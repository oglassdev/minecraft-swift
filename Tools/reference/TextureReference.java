import java.lang.reflect.Field;
import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.util.zip.CRC32;

/** Prints deterministic portal-frame checksums from the original Beta client. */
public final class TextureReference {
    public static void main(String[] arguments) throws Exception {
        PrintStream output = System.out;
        System.setOut(new PrintStream(new ByteArrayOutputStream()));
        Class<?> portalClass = Class.forName("hs");
        Object portal = portalClass.getConstructor().newInstance();
        Field field = portalClass.getDeclaredField("h");
        field.setAccessible(true);
        byte[][] frames = (byte[][]) field.get(portal);
        System.setOut(output);
        System.out.println("[");
        for (int index = 0; index < frames.length; index++) {
            CRC32 checksum = new CRC32();
            checksum.update(frames[index]);
            System.out.printf("  %d%s%n", checksum.getValue(), index == frames.length - 1 ? "" : ",");
        }
        System.out.println("]");
    }
}
