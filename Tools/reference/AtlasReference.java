import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;

/** Prints isolated-block terrain tiles from the unmodified Beta 1.7.3 client. */
public final class AtlasReference {
    public static void main(String[] arguments) throws Exception {
        Class<?> blockClass = Class.forName("uu");
        Object[] blocks = (Object[]) field(blockClass, "m").get(null);
        Class<?> accessClass = Class.forName("xp");
        Class<?> materialClass = Class.forName("ln");
        Object air = field(materialClass, "a").get(null);
        Field material = field(blockClass, "bA");
        boolean[] opaque = (boolean[]) field(blockClass, "o").get(null);
        int[] current = new int[2];
        Object world = Proxy.newProxyInstance(accessClass.getClassLoader(), new Class<?>[] {accessClass},
            (proxy, method, values) -> {
                boolean center = values != null && values.length >= 3
                    && (int) values[0] == 0 && (int) values[1] == 0 && (int) values[2] == 0;
                switch (method.getName()) {
                    case "e": return center ? current[1] : 0;
                    case "f": return center ? material.get(blocks[current[0]]) : air;
                    case "g":
                    case "h": return center && opaque[current[0]];
                    case "c": return 1.0f;
                    case "a":
                        if (method.getReturnType() == int.class) return center ? current[0] : 0;
                        if (method.getReturnType() == float.class) return 1.0f;
                        return null;
                    case "b": return null;
                    default: throw new UnsupportedOperationException(method.toString());
                }
            });
        Method texture = blockClass.getDeclaredMethod("a", accessClass,
            int.class, int.class, int.class, int.class);
        texture.setAccessible(true);
        for (int id = 1; id <= 96; id++) {
            for (int side = 0; side < 6; side++) {
                for (int metadata = 0; metadata < 16; metadata++) {
                    current[0] = id;
                    current[1] = metadata;
                    try {
                        Object tile = texture.invoke(blocks[id], world, 0, 0, 0, side);
                        System.out.printf("%d,%d,%d,%d%n", id, side, metadata, tile);
                    } catch (InvocationTargetException exception) {
                        System.out.printf("%d,%d,%d,error%n", id, side, metadata);
                    }
                }
            }
        }
    }

    private static Field field(Class<?> owner, String name) throws ReflectiveOperationException {
        Field field = owner.getDeclaredField(name);
        field.setAccessible(true);
        return field;
    }
}
