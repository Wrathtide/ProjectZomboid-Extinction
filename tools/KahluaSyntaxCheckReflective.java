import java.io.FileReader;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.nio.file.Path;

public final class KahluaSyntaxCheckReflective {
    private KahluaSyntaxCheckReflective() {
    }

    public static void main(String[] args) throws Exception {
        Class<?> platformClass = Class.forName("se.krka.kahlua.j2se.J2SEPlatform");
        Object platform = platformClass.getMethod("getInstance").invoke(null);
        Object environment = platformClass.getMethod("newEnvironment").invoke(platform);
        Class<?> compilerClass = Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler");
        Method loadReader = null;
        for (Method method : compilerClass.getMethods()) {
            if (method.getName().equals("loadis") && method.getParameterCount() == 3
                    && method.getParameterTypes()[0].getName().equals("java.io.Reader")) {
                loadReader = method;
                break;
            }
        }
        if (loadReader == null) throw new IllegalStateException("Brak metody kompilatora Lua.");
        for (String argument : args) {
            Path path = Path.of(argument).toAbsolutePath().normalize();
            try (FileReader reader = new FileReader(path.toFile())) {
                try {
                    loadReader.invoke(null, reader, "@" + path, environment);
                } catch (InvocationTargetException exception) {
                    Throwable cause = exception.getCause();
                    if (cause instanceof Exception) throw (Exception) cause;
                    throw exception;
                }
            }
            System.out.println("OK Lua: " + path);
        }
    }
}
