import java.util.HashMap;
import java.util.Map;
import java.util.Random;

// Executes the original synchronous generation-fluid callbacks in a 120-block chute.
public class FluidParity extends TerrainParity {
    static class Provider implements cl {
        final Map<Long, lm> chunks = new HashMap<>();
        Provider(fd world) {
            for (int cx = -1; cx <= 1; cx++) {
                for (int cz = -1; cz <= 1; cz++) {
                    byte[] blocks = new byte[32768];
                    if (cx == 0 && cz == 0) {
                        for (int y = 0; y < 128; y++) {
                            for (int[] p : new int[][] {{7, 8}, {9, 8}, {8, 7}, {8, 9}}) {
                                blocks[p[0] << 11 | p[1] << 7 | y] = 1;
                            }
                        }
                        blocks[8 << 11 | 8 << 7] = 1;
                        blocks[8 << 11 | 8 << 7 | 121] = 1;
                    }
                    chunks.put(chunkKey(cx, cz), new lm(world, blocks, cx, cz));
                }
            }
        }
        public boolean a(int x, int z) { return chunks.containsKey(chunkKey(x, z)); }
        public lm b(int x, int z) { return chunks.get(chunkKey(x, z)); }
        public lm c(int x, int z) { return b(x, z); }
        public void a(cl provider, int x, int z) {}
        public boolean a(boolean save, yb progress) { return true; }
        public boolean a() { return false; }
        public boolean b() { return true; }
        public String c() { return "Fluid parity provider"; }
    }
    public static void main(String[] args) throws Exception {
        fd world = world(0);
        Provider provider = new Provider(world);
        set(world, "v", provider);
        world.r = new Random(42);
        world.f(8, 120, 8, 8);
        world.a = true;
        uu.B.a(world, 8, 120, 8, new Random(0));
        world.a = false;
        lm chunk = provider.b(0, 0);
        byte[] metadata = new byte[32768];
        for (int i = 0; i < metadata.length; i++) { metadata[i] = (byte) chunk.e.a(i >> 11, i & 127, i >> 7 & 15); }
        System.out.printf("chute blocks%016x metadata%016x random%d%n", hash(chunk.b), hash(metadata), world.r.nextLong());
    }
}
