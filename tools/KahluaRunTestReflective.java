import java.io.FileReader;
import java.lang.reflect.Method;

/** Runs supplied Lua files in one isolated instance of the game's interpreter. */
public final class KahluaRunTestReflective {
    public static void main(String[] args) throws Exception {
        Class<?> platformClass = Class.forName("se.krka.kahlua.j2se.J2SEPlatform");
        Class<?> platformInterface = Class.forName("se.krka.kahlua.vm.Platform");
        Class<?> tableClass = Class.forName("se.krka.kahlua.vm.KahluaTable");
        Object platform = platformClass.getMethod("getInstance").invoke(null);
        Object environment = platformClass.getMethod("newEnvironment").invoke(platform);
        Class<?> threadClass = Class.forName("se.krka.kahlua.vm.KahluaThread");
        Object thread = threadClass.getConstructor(platformInterface, tableClass).newInstance(platform, environment);
        threadClass.getField("debugOwnerThread").set(thread, Thread.currentThread());
        Class<?> compilerClass = Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler");
        Method compile = compilerClass.getMethod("loadis", java.io.Reader.class, String.class, tableClass);
        Method call = threadClass.getMethod("pcall", Object.class, Object[].class);
        for (String path : args) {
            try (FileReader reader = new FileReader(path)) {
                Object closure = compile.invoke(null, reader, "@" + path, environment);
                Object[] result = (Object[]) call.invoke(thread, closure, new Object[0]);
                if (!Boolean.TRUE.equals(result[0])) {
                    throw new AssertionError("Blad testu Lua: " + java.util.Arrays.toString(result));
                }
                System.out.println("OK wykonanie Lua: " + path);
            }
        }
    }
}
