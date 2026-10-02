import java.io.StringReader;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

/** Uses the game's own Workshop API. Never creates a new Workshop item. */
public final class PublishSteamWorkshopReflective {
    private static final String ITEM_ID = "3809176497";

    @SuppressWarnings("unchecked")
    public static void main(String[] args) throws Exception {
        if (args.length < 1 || args.length > 2) throw new IllegalArgumentException("Podaj katalog pakietu i opcjonalnie --publish.");
        boolean publish = args.length == 2 && args[1].equals("--publish");
        if (args.length == 2 && !publish) throw new IllegalArgumentException("Nieznana opcja.");
        Path staging = Path.of(args[0]).toRealPath();
        Path expected = Path.of(System.getProperty("user.home"), "Zomboid", "Workshop", "Extinction").toRealPath();
        if (!staging.equals(expected)) throw new IllegalArgumentException("Nieoczekiwany katalog pakietu.");
        String info = Files.readString(staging.resolve("Contents/mods/Extinction/42.20/mod.info"));
        if (!info.lines().anyMatch(s -> s.equals("modversion=1.1.0"))) throw new IllegalStateException("Niepoprawna wersja pakietu.");
        Path preview = staging.resolve("preview.png");
        if (Files.size(preview) >= 1024 * 1024) throw new IllegalStateException("Podglad przekracza limit Workshop.");

        Class<?> itemClass = Class.forName("zombie.core.znet.SteamWorkshopItem");
        Object item = itemClass.getConstructor(String.class).newInstance(staging.toString());
        if (!Boolean.TRUE.equals(itemClass.getMethod("readWorkshopTxt").invoke(item))) throw new IllegalStateException("Nie odczytano metadanych Workshop.");
        if (!ITEM_ID.equals(itemClass.getMethod("getID").invoke(item))) throw new IllegalStateException("Niepoprawny identyfikator Workshop.");
        if (!"Extinction".equals(itemClass.getMethod("getTitle").invoke(item))) throw new IllegalStateException("Niepoprawny tytul Workshop.");
        if (!"public".equals(itemClass.getMethod("getVisibility").invoke(item))) throw new IllegalStateException("Niepoprawna widocznosc Workshop.");
        String description = (String) itemClass.getMethod("getDescription").invoke(item);
        if (description.getBytes(StandardCharsets.UTF_8).length >= 8000) throw new IllegalStateException("Opis przekracza limit Workshop.");
        System.out.println("OK pakiet 1.1.0, istniejacy przedmiot, publiczna widocznosc, podglad i opis.");
        if (!publish) return;

        // Capture the genuine success/error callbacks through the game's Lua
        // event dispatcher, rather than treating submitUpdate()==true as success.
        Class<?> platformClass = Class.forName("se.krka.kahlua.j2se.J2SEPlatform");
        Class<?> platformInterface = Class.forName("se.krka.kahlua.vm.Platform");
        Class<?> tableClass = Class.forName("se.krka.kahlua.vm.KahluaTable");
        Object platform = platformClass.getMethod("getInstance").invoke(null);
        Object environment = platformClass.getMethod("newEnvironment").invoke(platform);
        Class<?> threadClass = Class.forName("se.krka.kahlua.vm.KahluaThread");
        Object thread = threadClass.getConstructor(platformInterface, tableClass).newInstance(platform, environment);
        threadClass.getField("debugOwnerThread").set(thread, Thread.currentThread());
        Class<?> manager = Class.forName("zombie.Lua.LuaManager");
        manager.getField("platform").set(null, platform);
        manager.getField("env").set(null, environment);
        manager.getField("thread").set(null, thread);
        Class<?> callerClass = Class.forName("se.krka.kahlua.integration.LuaCaller");
        Object caller = callerClass.getConstructor(platformInterface).newInstance(platform);
        manager.getField("caller").set(null, caller);
        Method rawGet = tableClass.getMethod("rawget", Object.class);
        Method compile = Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler")
            .getMethod("loadis", java.io.Reader.class, String.class, tableClass);
        Object setup = compile.invoke(null, new StringReader(
            "function WorkshopSuccess(legal) WorkshopDone=true; WorkshopLegal=legal end\n"
            + "function WorkshopFailure(code) WorkshopDone=true; WorkshopError=code end"),
            "@WorkshopPublisher", environment);
        Object[] executed = (Object[]) threadClass.getMethod("pcall", Object.class, Object[].class)
            .invoke(thread, setup, new Object[0]);
        if (!Boolean.TRUE.equals(executed[0])) throw new IllegalStateException("Nie przygotowano odbioru potwierdzen.");
        Class<?> events = Class.forName("zombie.Lua.LuaEventManager");
        String[] eventNames = { "OnSteamWorkshopItemUpdated", "OnSteamWorkshopItemNotUpdated" };
        String[] callbacks = { "WorkshopSuccess", "WorkshopFailure" };
        for (int i = 0; i < eventNames.length; i++) {
            Object event = events.getMethod("AddEvent", String.class).invoke(null, eventNames[i]);
            ((List<Object>) event.getClass().getField("callbacks").get(event))
                .add(rawGet.invoke(environment, callbacks[i]));
        }
        Class<?> steam = Class.forName("zombie.core.znet.SteamUtils");
        Class<?> workshop = Class.forName("zombie.core.znet.SteamWorkshop");
        boolean initialized = false;
        try {
            steam.getMethod("init").invoke(null);
            if (!Boolean.TRUE.equals(steam.getMethod("isSteamModeEnabled").invoke(null))) {
                throw new IllegalStateException("Steam nie jest gotowy; niczego nie wyslano.");
            }
            workshop.getMethod("init").invoke(null);
            initialized = true;
            itemClass.getMethod("setChangeNote", String.class).invoke(item,
                "Update 1.1.0: optional natural extinction, independent animal hunting, native skeletons, diagnostics, and protection for existing fixed-timeline saves.");
            if (!Boolean.TRUE.equals(itemClass.getMethod("submitUpdate").invoke(item))) {
                throw new IllegalStateException("Steam odrzucil rozpoczecie aktualizacji.");
            }
            Method runLoop = steam.getMethod("runLoop");
            long deadline = System.nanoTime() + 180_000_000_000L;
            while (!Boolean.TRUE.equals(rawGet.invoke(environment, "WorkshopDone"))) {
                runLoop.invoke(null);
                if (System.nanoTime() >= deadline) throw new IllegalStateException("Brak potwierdzenia Steam; wynik publikacji nieznany.");
                Thread.sleep(100);
            }
            Object error = rawGet.invoke(environment, "WorkshopError");
            if (error != null) throw new IllegalStateException("Steam odrzucil aktualizacje, kod=" + error);
            if (Boolean.TRUE.equals(rawGet.invoke(environment, "WorkshopLegal"))) {
                throw new IllegalStateException("Steam wymaga akceptacji umowy Workshop przez wlasciciela.");
            }
            System.out.println("STEAM_CONFIRMED_UPDATE " + ITEM_ID);
        } finally {
            if (initialized) workshop.getMethod("shutdown").invoke(null);
            steam.getMethod("shutdown").invoke(null);
        }
    }
}
