import java.io.File;
import java.nio.file.Files;
import java.util.HashMap;
import java.util.Map;

/** Runs the original Beta lighting engine on a normally initialized, finite test world. */
public class LightingParity {
    private static final int[][] SOURCES = {{15, 50, 8, 50}, {8, 50, 8, 89}, {23, 50, 8, 11}};

    private static final class Provider implements cl {
        final fd world;
        final Map<Long, lm> chunks = new HashMap<>();

        Provider(fd world) { this.world = world; }
        static long key(int x, int z) { return ((long)x << 32) ^ (z & 0xffffffffL); }
        public boolean a(int x, int z) { return chunks.containsKey(key(x, z)); }
        public lm b(int x, int z) {
            lm chunk = chunks.get(key(x, z));
            if (chunk == null) throw new IllegalStateException("Requested unloaded chunk " + x + "," + z);
            return chunk;
        }
        public lm c(int x, int z) { return b(x, z); }
        public void a(cl provider, int x, int z) {}
        public boolean a(boolean all, yb progress) { return true; }
        public boolean a() { return false; }
        public boolean b() { return false; }
        public String c() { return "LightingParity"; }
    }

    private static final class World extends fd {
        World(File directory, boolean nether) {
            super(new fm(directory, "save", false), "LightingParity", nether ? new wd() : new rh(), 1L);
        }
        @Override protected cl b() { return new Provider(this); }
        Provider provider() { return (Provider)w(); }
    }

    private static void raw(World world, int x, int y, int z, int id) {
        world.c(x >> 4, z >> 4).b[((x & 15) << 11) | ((z & 15) << 7) | y] = (byte)id;
    }

    private static void drain(World world) {
        int batches = 0;
        while (world.j()) {
            if (++batches > 100000) throw new IllegalStateException("Lighting failed to settle");
        }
    }

    private static void settleAll(World world) {
        for (lm chunk : world.provider().chunks.values()) {
            world.a(eb.a, chunk.j * 16, 0, chunk.k * 16, chunk.j * 16 + 15, 127, chunk.k * 16 + 15);
            world.a(eb.b, chunk.j * 16, 0, chunk.k * 16, chunk.j * 16 + 15, 127, chunk.k * 16 + 15);
        }
        drain(world);
    }

    private static String hash(byte[] values) {
        long hash = 0xcbf29ce484222325L;
        for (byte value : values) { hash ^= value & 255; hash *= 0x100000001b3L; }
        return Long.toUnsignedString(hash, 16);
    }

    private static byte[] unpack(wi nibble) {
        byte[] result = new byte[32768];
        for (int i = 0; i < result.length; i++) result[i] = (byte)((nibble.a[i >> 1] >> ((i & 1) * 4)) & 15);
        return result;
    }

    private static void capture(World world, File output, String name) throws Exception {
        for (int x = 0; x <= 1; x++) {
            lm chunk = world.c(x, 0);
            byte[] sky = unpack(chunk.f), block = unpack(chunk.g);
            Files.write(new File(output, name + "-" + x + "-sky.bin").toPath(), sky);
            Files.write(new File(output, name + "-" + x + "-block.bin").toPath(), block);
            System.out.println(name + " " + x + " " + hash(sky) + " " + hash(block));
        }
        for (int[] p : new int[][]{{4,71,8},{4,70,8},{4,69,8},{12,70,8},{12,69,8},{20,70,8},
                                  {20,69,8},{28,70,8},{28,69,8},{16,50,8},{8,50,8},{23,50,8}}) {
            System.out.println(name + " sample " + p[0] + " " + p[1] + " " + p[2] + " "
                + world.a(eb.a, p[0], p[1], p[2]) + " " + world.a(eb.b, p[0], p[1], p[2]));
        }
    }

    private static World scene(File output, boolean nether) {
        World world = new World(output, nether);
        for (int x = -1; x <= 2; x++) for (int z = -1; z <= 1; z++) {
            lm chunk = new lm(world, new byte[32768], x, z);
            world.provider().chunks.put(Provider.key(x, z), chunk);
            for (int bx = 0; bx < 16; bx++) for (int bz = 0; bz < 16; bz++) chunk.b[(bx << 11) | (bz << 7)] = 7;
        }
        for (int x = 0; x < 32; x++) for (int z = 0; z < 16; z++) raw(world, x, 70, z, 1);
        int[] materials = {18, 9, 79, 30};
        for (int panel = 0; panel < materials.length; panel++) {
            for (int x = 2 + panel * 8; x <= 6 + panel * 8; x++) {
                for (int z = 6; z <= 10; z++) raw(world, x, 70, z, materials[panel]);
            }
        }
        for (lm chunk : world.provider().chunks.values()) chunk.c();
        settleAll(world);
        return world;
    }

    private static void addSources(World world) {
        for (int[] p : SOURCES) {
            world.c(p[0], p[1] - 1, p[2], 1);
            world.c(p[0], p[1], p[2], p[3]);
        }
        drain(world);
    }

    public static void main(String[] args) throws Exception {
        File output = new File(args.length == 0 ? ".build/reference/lighting" : args[0]);
        output.mkdirs();
        Class.forName("uu");
        World world = scene(output, false);
        capture(world, output, "materials");
        addSources(world);
        capture(world, output, "sources");
        for (int[] p : SOURCES) world.c(p[0], p[1], p[2], 0);
        drain(world);
        capture(world, output, "removed");
        World nether = scene(new File(output, "nether"), true);
        addSources(nether);
        capture(nether, output, "nether");
    }
}
