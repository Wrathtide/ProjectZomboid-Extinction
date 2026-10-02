import java.io.File;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.nio.file.Path;
import java.util.List;

/** Uses the installed game's parsers and condition evaluator, without launching a world. */
public final class AnimalBiteXmlCheckReflective {
    private static final String ACTIVE = "ExtinctionAnimalBiteActive";
    private static Object variables;
    private static Method setBoolean;
    private static Method clearVariables;
    private static Object context;
    private static Class<?> stateClass;
    private static Class<?> transitionClass;
    private static int assertions;

    private static void check(boolean result, String message) {
        if (!result) throw new AssertionError(message);
        assertions++;
    }

    private static void reset(String... enabled) throws Exception {
        clearVariables.invoke(variables);
        for (String name : new String[] { ACTIVE, "bClient", "bDead", "bOnFloor", "hashitreaction",
                "bAttack", "isFacingTarget", "bLunge", "bPathfind", "bMoving", "bMovingNetwork",
                "ZombieBiteDone", "bEatBodyTarget", "bCanSeeTarget", "useRagdollVehicleCollision" }) {
            setBoolean.invoke(variables, name, false);
        }
        for (String name : enabled) setBoolean.invoke(variables, name, true);
    }

    private static boolean passes(Object transition, Object state) throws Exception {
        return (boolean) transitionClass.getMethod("passes", context.getClass(), stateClass)
                .invoke(transition, context, state);
    }

    private static Object loadState(Path path, String name) throws Exception {
        Object state = stateClass.getConstructor(String.class).newInstance(name);
        stateClass.getMethod("parse", File.class).invoke(state, path.toFile());
        stateClass.getMethod("sortTransitions").invoke(state);
        return state;
    }

    @SuppressWarnings("unchecked")
    private static List<Object> transitions(Object state) throws Exception {
        return (List<Object>) stateClass.getField("transitions").get(state);
    }

    public static void main(String[] args) throws Exception {
        Path media = Path.of(args[0]).toAbsolutePath();
        Class<?> sourceClass = Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimationVariableSource");
        variables = sourceClass.getConstructor().newInstance();
        setBoolean = sourceClass.getMethod("setVariable", String.class, boolean.class);
        clearVariables = sourceClass.getMethod("clearVariables");
        Class<?> ownerClass = Class.forName("zombie.core.skinnedmodel.advancedanimation.IAnimatable");
        Object owner = Proxy.newProxyInstance(ownerClass.getClassLoader(), new Class<?>[] { ownerClass },
            (proxy, method, values) -> {
                if (method.getName().equals("getActionContext")) return context;
                if (method.getName().equals("getUID")) return "ExtinctionXmlTest";
                try { return sourceClass.getMethod(method.getName(), method.getParameterTypes()).invoke(variables, values); }
                catch (NoSuchMethodException ignored) {
                    if (method.getReturnType() == boolean.class) return false;
                    if (method.getReturnType() == int.class) return 0;
                    return null;
                }
            });
        context = Class.forName("zombie.characters.action.ActionContext").getConstructor(ownerClass).newInstance(owner);
        Class<?> conditionClass = Class.forName("zombie.characters.action.IActionCondition");
        Class<?> factoryInterface = Class.forName("zombie.characters.action.IActionCondition$IFactory");
        Object factory = Class.forName("zombie.characters.action.conditions.CharacterVariableCondition$Factory")
                .getConstructor().newInstance();
        Method register = conditionClass.getMethod("registerFactory", String.class, factoryInterface);
        register.invoke(null, "isTrue", factory);
        register.invoke(null, "isFalse", factory);
        register.invoke(null, "equals", factory);
        stateClass = Class.forName("zombie.characters.action.ActionState");
        transitionClass = Class.forName("zombie.characters.action.ActionTransition");
        for (String stateName : new String[] { "idle", "lunge", "thump", "turnalerted", "walktoward", "pathfind" }) {
            String fileName = stateName.equals("walktoward") ? "to_lunge.xml"
                    : stateName.equals("pathfind") ? "to_idle.xml" : "to_attack.xml";
            Object state = loadState(media.resolve("actiongroups/zombie/" + stateName + "/" + fileName), stateName);
            List<Object> rules = transitions(state);
            check(rules.size() == (stateName.equals("pathfind") ? 3 : 2), "Missing native transition: " + stateName);
            Object custom = rules.get(0);
            check("attack".equals(transitionClass.getMethod("getTransitionTo").invoke(custom)), "Priority: " + stateName);
            reset(ACTIVE);
            check(passes(custom, state), "Animal attack did not enter: " + stateName);
            reset();
            check(!passes(custom, state), "Animal attack active without flag: " + stateName);
            for (String blocker : new String[] { "bClient", "bDead", "bOnFloor", "hashitreaction" }) {
                reset(ACTIVE, blocker);
                check(!passes(custom, state), "Ignored blocker " + blocker + ": " + stateName);
            }
            reset("bAttack", "isFacingTarget", "bLunge");
            check(passes(rules.get(1), state), "Native behavior changed: " + stateName);
            System.out.println("OK przejscia: " + stateName);
        }
        Object attack = loadState(media.resolve("actiongroups/zombie/attack/to_idle.xml"), "attack");
        List<Object> exitRules = transitions(attack);
        check(exitRules.size() == 4, "Missing attack exit branches");
        reset(ACTIVE, "ZombieBiteDone");
        for (Object rule : exitRules) check(!passes(rule, attack), "Premature animal attack exit");
        reset("ZombieBiteDone");
        check(exitRules.stream().anyMatch(rule -> {
            try { return passes(rule, attack); } catch (Exception e) { throw new RuntimeException(e); }
        }), "Native attack exit not restored");
        sourceClass.getMethod("clearVariable", String.class).invoke(variables, ACTIVE);
        check(exitRules.stream().anyMatch(rule -> {
            try { return passes(rule, attack); } catch (Exception e) { throw new RuntimeException(e); }
        }), "Native attack exit not restored with missing custom variable");
        Class<?> nodeClass = Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimNode");
        Object node = nodeClass.getMethod("Parse", String.class).invoke(null,
                media.resolve("AnimSets/zombie/attack/ExtinctionAnimalBite.xml").toString());
        check(node != null, "Native animation parser failed");
        check("Zombie_Bite_Success".equals(nodeClass.getField("animName").get(node)), "Wrong animation clip");
        check(nodeClass.getField("conditionPriority").getInt(node) == 100, "Wrong node priority");
        check(!nodeClass.getField("isLooped").getBoolean(node), "Animation must not loop");
        Method conditions = nodeClass.getMethod("checkConditions",
                Class.forName("zombie.core.skinnedmodel.advancedanimation.IAnimationVariableSource"));
        reset();
        check(!(boolean) conditions.invoke(node, variables), "Animation active without flag");
        reset(ACTIVE);
        check((boolean) conditions.invoke(node, variables), "Animation not selected with flag");
        Object nativeStart = nodeClass.getMethod("Parse", String.class).invoke(null,
                Path.of("media/AnimSets/zombie/attack/start.xml").toAbsolutePath().toString());
        check((int) nodeClass.getMethod("compareSelectionConditions", nodeClass).invoke(node, nativeStart) > 0,
                "Custom animation does not outrank native start");
        Class<?> animStateClass = Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimState");
        Object animState = animStateClass.getConstructor().newInstance();
        animStateClass.getMethod("addNode", nodeClass).invoke(animState, nativeStart);
        animStateClass.getMethod("addNode", nodeClass).invoke(animState, node);
        sourceClass.getMethod("setVariable", String.class, String.class).invoke(variables, "AttackOutcome", "start");
        sourceClass.getMethod("setVariable", String.class, String.class).invoke(variables, "AttackType", "bite");
        sourceClass.getMethod("setVariable", String.class, float.class).invoke(variables, "targetSeenTime", 10f);
        Method select = animStateClass.getMethod("getAnimNodes",
                Class.forName("zombie.core.skinnedmodel.advancedanimation.IAnimationVariableSource"), List.class);
        List<?> selected = (List<?>) select.invoke(animState, variables, new java.util.ArrayList<>());
        check(selected.size() == 1 && selected.get(0) == node, "Native selector did not choose animal bite exclusively");
        sourceClass.getMethod("clearVariable", String.class).invoke(variables, ACTIVE);
        selected = (List<?>) select.invoke(animState, variables, new java.util.ArrayList<>());
        check(selected.size() == 1 && selected.get(0) == nativeStart, "Native selector did not restore ordinary attack");
        List<?> events = (List<?>) nodeClass.getField("events").get(node);
        check(events.size() == 3, "Missing animation events");
        String[] eventFlags = { "ExtinctionAnimalBiteStarted=true", "ExtinctionAnimalBiteContact=true", "ExtinctionAnimalBiteDone=true" };
        for (String flag : eventFlags) {
            Object event = events.stream().filter(value -> {
                try { return flag.equals(value.getClass().getField("parameterValue").get(value)); }
                catch (Exception e) { throw new RuntimeException(e); }
            }).findFirst().orElseThrow(() -> new AssertionError("Missing event: " + flag));
            check("SetVariable".equals(event.getClass().getField("eventName").get(event)), "Player-only event present");
            if (flag.contains("Contact")) {
                check("PERCENTAGE".equals(event.getClass().getField("time").get(event).toString()), "Wrong contact type");
                check(Math.abs(event.getClass().getField("timePc").getFloat(event) - 0.2f) < 0.001f, "Wrong contact time");
            } else check((flag.contains("Started") ? "START" : "END")
                    .equals(event.getClass().getField("time").get(event).toString()), "Wrong event time");
        }
        System.out.println("OK parser gry i warunki animacji: " + assertions + " sprawdzen. Renderowanie w grze nie bylo testowane.");
    }
}
