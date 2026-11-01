import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.Base64;

/** Captures the Java seed primitives and original Beta GameSettings defaults/read/write. */
public final class WorldLibraryParity {
    private static void capture(String label, kv options) {
        System.out.println(label + " " + options.a + " " + options.b + " " + options.c + " "
            + options.d + " " + options.e + " " + options.I + " " + options.f + " " + options.g
            + " " + options.h + " " + options.i + " " + options.y + " " + options.j + " "
            + options.k + " " + options.l + " " + options.C);
        for (qb key : options.w) System.out.println(label + " binding " + key.a + " " + key.b);
    }

    public static void main(String[] args) throws Exception {
        File directory = new File(args.length == 0 ? ".build/reference/world-library" : args[0]);
        directory.mkdirs();
        for (String text : new String[]{"", "0", "+0", "-0", "000", "123", "-123", "+123",
            "9223372036854775807", "-9223372036854775808", "9223372036854775808", "-9223372036854775809",
            " 123", "123 ", " ", "\t", "hello", "Glacier", "404", "😀", "A😀B", "١٢٣", "１２３", "²", "𝟙𝟚𝟛"}) {
            long seed = 42;
            if (!text.isEmpty()) {
                try { long number = Long.parseLong(text); if (number != 0) seed = number; }
                catch (NumberFormatException error) { seed = text.hashCode(); }
            }
            System.out.println("seed " + Base64.getEncoder().encodeToString(text.getBytes(StandardCharsets.UTF_8)) + " " + seed);
        }
        kv options = new kv();
        capture("default", options);
        java.lang.reflect.Field file = kv.class.getDeclaredField("N");
        file.setAccessible(true);
        file.set(options, new File(directory, "defaults.txt"));
        options.b();
        File input = new File(directory, "input.txt");
        Files.writeString(input.toPath(), String.join("\n",
            "music:true", "sound:false", "mouseSensitivity: 0.75f", "invertYMouse:true", "viewDistance:3",
            "guiScale:2", "bobView:false", "anaglyph3d:true", "advancedOpengl:true", "fpsLimit:2",
            "difficulty:3", "fancyGraphics:false", "ao:false", "skin:Custom", "lastServer:example.org:25565",
            "key_key.forward:200", "key_key.inventory:23", "music:bad", "viewDistance:2147483648",
            "key_key.jump:bad", "futureOption:retain:this", "# retained comment") + "\n");
        file.set(options, input);
        options.a();
        capture("loaded", options);
        file.set(options, new File(directory, "roundtrip.txt"));
        options.b();
        for (float sensitivity : new float[]{0,0.5f,0.75f,1}) {
            float base = sensitivity * 0.6f + 0.2f;
            float radians = (float)((base * base * base * 8f) * 0.15 * Math.PI / 180);
            System.out.println("sensitivity " + sensitivity + " " + Integer.toHexString(Float.floatToRawIntBits(radians)));
        }
    }
}
