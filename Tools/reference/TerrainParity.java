import java.io.File;
import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.stream.LongStream;

// Invokes the locally downloaded, unmodified Beta client; no game implementation is included here.
// javac -cp .build/reference/b1.7.3.jar -d .build/reference Tools/reference/TerrainParity.java
// java -cp .build/reference/b1.7.3.jar:.build/reference TerrainParity [--population [seed]]
public class TerrainParity {
    static void set(Object target, String name, Object value) throws Exception {
        for (Class<?> type = target.getClass(); type != null; type = type.getSuperclass()) {
            try {
                Field field = type.getDeclaredField(name);
                field.setAccessible(true);
                field.set(target, value);
                return;
            } catch (NoSuchFieldException ignored) {}
        }
        throw new NoSuchFieldException(name);
    }

    static void seedChunkRandom(yf generator, int x, int z) throws Exception {
        Field field = yf.class.getDeclaredField("j");
        field.setAccessible(true);
        ((Random) field.get(generator)).setSeed(x * 341873128712L + z * 132897987541L);
    }

    static long chunkKey(int x, int z) { return ((long) x << 32) ^ (z & 0xffffffffL); }

    static long hash(byte[] bytes) {
        long result = 0xcbf29ce484222325L;
        for (byte value : bytes) {
            result ^= Byte.toUnsignedInt(value);
            result *= 0x100000001b3L;
        }
        return result;
    }

    static class MemorySaveHandler implements wt {
        public ei c() { return null; }
        public void b() {}
        public bf a(xa provider) { return null; }
        public void a(ei info, List players) {}
        public void a(ei info) {}
        public File a(String name) { return null; }
    }

    // Retains the original World, Chunk, lighting, notifications and feature code.
    // Automatic neighboring-chunk population is disabled so the test population order is explicit.
    static class OriginalProvider implements cl {
        final fd world;
        final yf generator;
        final Map<Long, lm> chunks = new HashMap<>();

        OriginalProvider(fd world, long seed) {
            this.world = world;
            generator = new yf(world, seed);
        }

        public boolean a(int x, int z) { return chunks.containsKey(chunkKey(x, z)); }
        public lm b(int x, int z) { return c(x, z); }

        public lm c(int x, int z) {
            long key = chunkKey(x, z);
            lm existing = chunks.get(key);
            if (existing != null) { return existing; }
            byte[] blocks = new byte[32768];
            lm chunk = new lm(world, blocks, x, z);
            chunks.put(key, chunk);
            xv climate = world.a();
            kd[] biomes = climate.a((kd[]) null, x * 16, z * 16, 16, 16);
            generator.a(x, z, blocks, biomes, climate.a);
            try { seedChunkRandom(generator, x, z); }
            catch (Exception error) { throw new RuntimeException(error); }
            generator.a(x, z, blocks, biomes);
            new sq().a(null, world, x, z, blocks);
            chunk.c();
            return chunk;
        }

        public void a(cl provider, int x, int z) { generator.a(this, x, z); }
        public boolean a(boolean save, yb progress) { return true; }
        public boolean a() { return false; }
        public boolean b() { return true; }
        public String c() { return "Original parity provider"; }
    }

    static fd world(long seed) { return new fd(new MemorySaveHandler(), "Parity", new rh(), seed); }

    static void population(long[] seeds) throws Exception {
        for (long seed : seeds) {
            fd world = world(seed);
            OriginalProvider provider = new OriginalProvider(world, seed);
            set(world, "v", provider);
            for (int x = -1; x <= 2; x++) {
                for (int z = -1; z <= 2; z++) { provider.c(x, z); }
            }
            while (world.j()) {}
            provider.a(provider, 0, 0);
            int tiles = provider.chunks.values().stream().mapToInt(chunk -> chunk.l.size()).sum();
            if (System.getProperty("terrain.scan") != null && tiles == 0) { continue; }
            System.out.print("population " + seed);
            for (int x = 0; x <= 1; x++) {
                for (int z = 0; z <= 1; z++) {
                    lm chunk = provider.b(x, z);
                    System.out.printf(" %016x", hash(chunk.b));
                    if (Boolean.getBoolean("terrain.dump")) {
                        Files.write(Path.of(".build/reference/popfulljava-" + seed + "-" + x + "-" + z + ".bin"), chunk.b);
                    }
                }
            }
            System.out.println(" tiles " + tiles);
            if (Boolean.getBoolean("terrain.tiles")) { printTiles(provider); }
        }
    }

    static void printTiles(OriginalProvider provider) {
        List<ow> tiles = new ArrayList<>();
        for (lm chunk : provider.chunks.values()) {
            for (Object tile : chunk.l.values()) { tiles.add((ow) tile); }
        }
        tiles.sort(Comparator.comparingInt((ow tile) -> tile.e).thenComparingInt(tile -> tile.f).thenComparingInt(tile -> tile.g));
        for (ow tile : tiles) {
            System.out.print("tile " + tile.e + "," + tile.f + "," + tile.g);
            if (tile instanceof cy) { System.out.print(" spawner " + ((cy) tile).a()); }
            if (tile instanceof js) {
                js chest = (js) tile;
                System.out.print(" chest metadata " + provider.world.e(tile.e, tile.f, tile.g));
                for (int slot = 0; slot < chest.a(); slot++) {
                    iz stack = chest.f_(slot);
                    if (stack != null) { System.out.printf(" %d:%d/%d/%d", slot, stack.c, stack.a, stack.h()); }
                }
            }
            System.out.println();
        }
    }

    public static void main(String[] args) throws Exception {
        if (args.length > 0 && (args[0].equals("--population") || args[0].equals("--full-population"))) {
            long[] seeds = args.length > 1 ? new long[] {Long.parseLong(args[1])} : new long[] {0, 1, -1, 123456789L, 95};
            if (System.getProperty("terrain.scan") != null) { seeds = LongStream.range(0, Long.getLong("terrain.scan")).toArray(); }
            population(seeds);
            return;
        }
        for (long seed : new long[] {0, 1, -1, 123456789L}) {
            am noise = new am(new Random(seed));
            System.out.printf("perlin %d %.17g %.17g %.17g%n", seed, noise.a(0.0, 0.0, 0.0),
                noise.a(-30.5, 25.25, 42.75), noise.a(12550824.0, 10.0, -5.0));
            uf octaves = new uf(new Random(seed), 4);
            double[] volume = octaves.a(null, -30.5, 25.25, 42.75, 3, 4, 2, .03125, .125, .03125);
            System.out.print("octave3d " + seed);
            for (int index : new int[] {0, 1, 5, 11, 17, 23}) { System.out.printf(" %.17g", volume[index]); }
            System.out.println();
            double[] plane = octaves.a(null, -30.5, 25.25, 42.75, 3, 1, 2, .03125, .125, .03125);
            System.out.print("octave2d " + seed);
            for (double value : plane) { System.out.printf(" %.17g", value); }
            System.out.println();
            fd world = world(seed);
            xv climate = world.a();
            kd[] biomes = climate.a((kd[]) null, -32, 48, 16, 16);
            System.out.print("climate " + seed);
            for (int index : new int[] {0, 1, 17, 128, 255}) {
                System.out.printf(" %.17g %.17g %s", climate.a[index], climate.b[index], biomes[index].n.replace(" ", "_"));
            }
            System.out.println();
            yf generator = new yf(world, seed);
            for (int[] position : new int[][] {{0, 0}, {1, -2}, {-7, 9}, {100, 100}}) {
                int x = position[0], z = position[1];
                byte[] blocks = new byte[32768];
                biomes = climate.a((kd[]) null, x * 16, z * 16, 16, 16);
                generator.a(x, z, blocks, biomes, climate.a);
                seedChunkRandom(generator, x, z);
                generator.a(x, z, blocks, biomes);
                long surface = hash(blocks);
                new sq().a(null, world, x, z, blocks);
                System.out.printf("chunk %d %d %d %016x %016x%n", seed, x, z, surface, hash(blocks));
            }
        }
    }
}
