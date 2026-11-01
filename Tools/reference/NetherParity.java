import java.util.HashMap;
import java.util.Map;
import java.util.Random;
import java.nio.file.Files;
import java.nio.file.Path;

// Compile with TerrainParity.java against the local original Beta client jar.
public class NetherParity extends TerrainParity {
    static class NetherProvider implements cl {
        final fd world;
        final qn generator;
        final Map<Long, lm> chunks = new HashMap<>();

        NetherProvider(fd world, long seed) {
            this.world = world;
            generator = new qn(world, seed);
        }
        public boolean a(int x, int z) { return chunks.containsKey(chunkKey(x, z)); }
        public lm b(int x, int z) { return c(x, z); }
        public lm c(int x, int z) {
            long key = chunkKey(x, z);
            lm existing = chunks.get(key);
            if (existing != null) { return existing; }
            lm chunk = generator.b(x, z);
            chunks.put(key, chunk);
            chunk.d();
            chunk.e();
            return chunk;
        }
        public void a(cl provider, int x, int z) { generator.a(this, x, z); }
        public boolean a(boolean save, yb progress) { return true; }
        public boolean a() { return false; }
        public boolean b() { return true; }
        public String c() { return "Original Nether parity provider"; }
    }

    static fd netherWorld(long seed) { return new fd(new MemorySaveHandler(), "Nether parity", new wd(), seed); }

    static void farLands() throws Exception {
        fd overworld = world(0);
        OriginalProvider normal = new OriginalProvider(overworld, 0);
        set(overworld, "v", normal);
        fd nether = netherWorld(0);
        NetherProvider hell = new NetherProvider(nether, 0);
        set(nether, "v", hell);
        for (int[] p : new int[][] {{784425, 0}, {784426, 0}, {784427, 0}, {-784426, 0},
                {-784427, 0}, {0, 784426}, {0, -784427}, {784426, 784426}}) {
            System.out.printf("farlands %d %d %016x %016x%n", p[0], p[1],
                hash(normal.c(p[0], p[1]).b), hash(hell.c(p[0], p[1]).b));
        }
    }

    // Only the world storage is synthetic; the unmodified original Teleporter is invoked.
    static class PortalWorld extends fd {
        final Map<Long, Integer> edits = new HashMap<>();
        final int shape;
        PortalWorld(int shape) {
            super(new MemorySaveHandler(), "Portal parity", new wd(), 0);
            this.shape = shape;
        }
        long key(int x, int y, int z) { return ((long) x << 40) ^ ((z & 0xffffffffL) << 8) ^ y; }
        public int a(int x, int y, int z) {
            if (y < 0 || y >= 128) { return 0; }
            Integer edited = edits == null ? null : edits.get(key(x, y, z));
            if (edited != null) { return edited; }
            if (shape == 0) { return y < 64 ? 1 : 0; }
            return shape == 2 && x == 0 && y >= 64 && y < 68 ? 0 : 87;
        }
        public boolean f(int x, int y, int z, int block) {
            if (y < 0 || y >= 128) { return false; }
            edits.put(key(x, y, z), block);
            return true;
        }
        public void i(int x, int y, int z, int block) {}
        long regionHash() {
            byte[] blocks = new byte[9 * 32768];
            int i = 0;
            for (int cx = -1; cx <= 1; cx++) {
                for (int cz = -1; cz <= 1; cz++) {
                    for (int x = 0; x < 16; x++) {
                        for (int z = 0; z < 16; z++) {
                            for (int y = 0; y < 128; y++) { blocks[i++] = (byte) a(cx * 16 + x, y, cz * 16 + z); }
                        }
                    }
                }
            }
            return hash(blocks);
        }
    }

    static void portals() throws Exception {
        double[][] positions = {{.25, 65, -.25}, {15.6, 40, 15.6}, {-15.6, 125, -15.6}, {.25, 65, -.25}};
        for (int index = 0; index < positions.length; index++) {
            PortalWorld world = new PortalWorld(index == 0 ? 0 : (index == 3 ? 2 : 1));
            qw entity = new qw(world);
            entity.bf = 0;
            entity.e(positions[index][0], positions[index][1], positions[index][2]);
            ur teleporter = new ur();
            Random random = new Random(index);
            set(teleporter, "a", random);
            teleporter.a(world, entity);
            System.out.printf("portal %d %.17g %.17g %.17g %016x %d%n", index,
                entity.aM, entity.aN, entity.aO, world.regionHash(), random.nextLong());
        }
    }

    public static void main(String[] args) throws Exception {
        if (args.length > 0 && args[0].equals("--farlands")) { farLands(); return; }
        if (args.length > 0 && args[0].equals("--portals")) { portals(); return; }
        boolean populated = args.length > 0 && args[0].equals("--population");
        for (long seed : new long[] {0, 1, -1, 123456789L}) {
            fd world = netherWorld(seed);
            NetherProvider provider = new NetherProvider(world, seed);
            set(world, "v", provider);
            if (populated) {
                for (int x = -1; x <= 2; x++) {
                    for (int z = -1; z <= 2; z++) { provider.c(x, z); }
                }
                while (world.j()) {}
                provider.a(provider, 0, 0);
                System.out.print("nether-population " + seed);
                for (int x = 0; x <= 1; x++) {
                    for (int z = 0; z <= 1; z++) {
                        byte[] blocks = provider.b(x, z).b;
                        System.out.printf(" %016x", hash(blocks));
                        if (Boolean.getBoolean("nether.dump")) {
                            Files.write(Path.of(".build/reference/nether-" + seed + "-" + x + "-" + z + ".bin"), blocks);
                        }
                    }
                }
                System.out.println();
                System.out.print("nether-metadata " + seed);
                for (int x = 0; x <= 1; x++) {
                    for (int z = 0; z <= 1; z++) {
                        lm chunk = provider.b(x, z);
                        byte[] metadata = new byte[32768];
                        for (int i = 0; i < metadata.length; i++) {
                            metadata[i] = (byte) chunk.e.a(i >> 11, i & 127, (i >> 7) & 15);
                        }
                        System.out.printf(" %016x", hash(metadata));
                    }
                }
                System.out.println();
            } else {
                for (int[] position : new int[][] {{0, 0}, {1, -2}, {-7, 9}, {100, 100}}) {
                    System.out.printf("nether %d %d %d %016x%n", seed, position[0], position[1],
                        hash(provider.b(position[0], position[1]).b));
                }
            }
        }
    }
}
