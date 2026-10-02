import java.io.File;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.w3c.dom.Element;

/** Tests native mod-file discovery, XML inheritance and animation selection; no rendered world. */
public final class AnimalBiteXmlCheckReflective {
    private static int assertions;
    private static void check(boolean result, String message) {
        if (!result) throw new AssertionError(message);
        assertions++;
    }

    @SuppressWarnings("unchecked")
    public static void main(String[] args) throws Exception {
        Path media = Path.of(args[0]).toAbsolutePath();
        Path probe = Path.of(args[1]).toAbsolutePath();
        Class<?> fsClass = Class.forName("zombie.ZomboidFileSystem");
        Object fs = fsClass.getField("instance").get(null);
        Object baseFolder = fsClass.getField("base").get(fs);
        baseFolder.getClass().getMethod("set", File.class).invoke(baseFolder, new File("."));
        Map<String, String> fileMap = (Map<String, String>) fsClass.getField("activeFileMap").get(fs);
        String overrideKey = "media/actiongroups/zombie/idle/to_attack.xml";
        fileMap.put(overrideKey, probe.toString());
        Class<?> conditionClass = Class.forName("zombie.characters.action.IActionCondition");
        Object factory = Class.forName("zombie.characters.action.conditions.CharacterVariableCondition$Factory")
                .getConstructor().newInstance();
        Method register = conditionClass.getMethod("registerFactory", String.class,
                Class.forName("zombie.characters.action.IActionCondition$IFactory"));
        register.invoke(null, "isTrue", factory);
        register.invoke(null, "isFalse", factory);
        Class<?> actionStateClass = Class.forName("zombie.characters.action.ActionState");
        Object actionState = actionStateClass.getConstructor(String.class).newInstance("idle");
        actionStateClass.getMethod("parse", File.class).invoke(actionState, Path.of(overrideKey).toAbsolutePath().toFile());
        List<?> rules = (List<?>) actionStateClass.getField("transitions").get(actionState);
        check(rules.size() == 1 && "attack".equals(rules.get(0).getClass()
                .getMethod("getTransitionTo").invoke(rules.get(0))), "Native absolute-path behavior changed");
        Element relative = (Element) Class.forName("zombie.util.PZXmlUtil").getMethod("parseXml", String.class)
                .invoke(null, overrideKey);
        check("ExtinctionProbe".equals(relative.getElementsByTagName("transitionTo").item(0).getTextContent()),
                "Relative override not resolved");
        fileMap.remove(overrideKey);
        System.out.println("OK odtworzenie bledu: absolutne sciezki actiongroups pomijaja nadpisanie moda.");

        Class<?> visitorClass = Class.forName("zombie.ZomboidFileSystem$IWalkFilesVisitor");
        Method discover = fsClass.getDeclaredMethod("walkGameAndModFilesInternal", File.class, String.class,
                boolean.class, visitorClass);
        discover.setAccessible(true);
        Class<?> sourceClass = Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimationVariableSource");
        Object variables = sourceClass.getConstructor().newInstance();
        Method bool = sourceClass.getMethod("setVariable", String.class, boolean.class);
        Method string = sourceClass.getMethod("setVariable", String.class, String.class);
        Class<?> nodeClass = Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimNode");
        Class<?> variableSource = Class.forName("zombie.core.skinnedmodel.advancedanimation.IAnimationVariableSource");
        Method parse = nodeClass.getMethod("Parse", String.class);
        Method conditions = nodeClass.getMethod("checkConditions", variableSource);
        Class<?> animStateClass = Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimState");
        Method addNode = animStateClass.getMethod("addNode", nodeClass);
        Method select = animStateClass.getMethod("getAnimNodes", variableSource, List.class);
        for (String state : new String[] { "idle", "turnalerted", "walktoward", "pathfind", "lunge", "thump", "attack" }) {
            List<File> discovered = new ArrayList<>();
            Object visitor = Proxy.newProxyInstance(visitorClass.getClassLoader(), new Class<?>[] { visitorClass },
                (proxy, method, values) -> {
                    if (method.getName().equals("visit")) {
                        File file = (File) values[0];
                        if (file.isFile() && file.getName().equals("ExtinctionAnimalBite.xml")) discovered.add(file);
                    }
                    return null;
                });
            discover.invoke(fs, media.getParent().toFile(), "media/AnimSets/zombie/" + state, false, visitor);
            check(discovered.size() == 1, "Native file walker missed mod node in " + state);
            Object node = parse.invoke(null, discovered.get(0).getAbsolutePath());
            check(node != null, "Native parser failed: " + state);
            check("Zombie_Bite_Success".equals(nodeClass.getField("animName").get(node)), "Wrong clip: " + state);
            check(nodeClass.getField("conditionPriority").getInt(node) == 100, "Wrong priority: " + state);
            check(!nodeClass.getField("isLooped").getBoolean(node), "Bite loops: " + state);
            check(!nodeClass.getField("useDeferredMovement").getBoolean(node), "Bite permits walking: " + state);
            check(nodeClass.getField("stopAnimOnExit").getBoolean(node), "Interrupted bite track not stopped: " + state);
            sourceClass.getMethod("clearVariables").invoke(variables);
            for (String name : new String[] { "bDead", "bOnFloor", "hashitreaction" }) bool.invoke(variables, name, false);
            check(!(boolean) conditions.invoke(node, variables), "Missing active flag selects bite: " + state);
            bool.invoke(variables, "ExtinctionAnimalBiteActive", true);
            check((boolean) conditions.invoke(node, variables), "Bite not selected: " + state);
            for (String blocker : new String[] { "bDead", "bOnFloor", "hashitreaction" }) {
                bool.invoke(variables, blocker, true);
                check(!(boolean) conditions.invoke(node, variables), "Ignored interruption: " + state + " " + blocker);
                bool.invoke(variables, blocker, false);
            }
            Object animationState = animStateClass.getConstructor().newInstance();
            try (var nativeFiles = Files.list(Path.of("media/AnimSets/zombie/" + state))) {
                for (Path file : nativeFiles.filter(p -> p.toString().endsWith(".xml")).toList()) {
                    Object vanilla = parse.invoke(null, file.toAbsolutePath().toString());
                    check(vanilla != null, "Vanilla XML failed: " + file);
                    addNode.invoke(animationState, vanilla);
                }
            }
            addNode.invoke(animationState, node);
            string.invoke(variables, "AttackOutcome", "start");
            string.invoke(variables, "AttackType", "bite");
            sourceClass.getMethod("setVariable", String.class, float.class).invoke(variables, "targetSeenTime", 10f);
            List<?> selected = (List<?>) select.invoke(animationState, variables, new ArrayList<>());
            check(selected.size() == 1 && selected.get(0) == node, "Native selector did not choose bite exclusively: " + state);
            sourceClass.getMethod("clearVariable", String.class).invoke(variables, "ExtinctionAnimalBiteActive");
            selected = (List<?>) select.invoke(animationState, variables, new ArrayList<>());
            check(!selected.contains(node), "Custom animation remains after flag cleared: " + state);
            List<?> events = (List<?>) nodeClass.getField("events").get(node);
            check(events.size() == 3, "Wrong event count: " + state);
            for (String suffix : new String[] { "Started", "Contact", "Done" }) {
                Object event = events.stream().filter(value -> {
                    try { return ("ExtinctionAnimalBite" + suffix + "=true")
                            .equals(value.getClass().getField("parameterValue").get(value)); }
                    catch (Exception e) { throw new RuntimeException(e); }
                }).findFirst().orElseThrow(() -> new AssertionError("Missing event " + suffix + ": " + state));
                check("SetVariable".equals(event.getClass().getField("eventName").get(event)), "Player-only event: " + state);
                String timing = suffix.equals("Contact") ? "PERCENTAGE" : suffix.equals("Started") ? "START" : "END";
                check(timing.equals(event.getClass().getField("time").get(event).toString()), "Wrong event timing: " + state);
                if (suffix.equals("Contact")) check(Math.abs(event.getClass().getField("timePc").getFloat(event) - 0.2f) < 0.001f,
                        "Wrong contact time: " + state);
            }
            System.out.println("OK wykrycie pliku, dziedziczenie XML i wybor animacji: " + state);
        }
        System.out.println("OK " + assertions + " sprawdzen natywnych klas. Renderowanie i trasa w swiecie nie byly testowane.");
    }
}
