import java.util.Random;

// Calls the original World.c(), World.d(), EntityPlayer constructor and Entity.preparePlayerToSpawn.
public class SpawnParity extends TerrainParity {
    static class SpawnWorld extends fd {
        SpawnWorld(long seed) { super(new MemorySaveHandler(), "Spawn parity", new rh(), seed); }
        void initial() { super.c(); }
    }
    static class SpawnPlayer extends gs {
        SpawnPlayer(fd world) { super(world); }
        public void v() {}
    }
    static class SparseWorld extends SpawnWorld {
        SparseWorld() { super(0); }
        public int a(int x, int y, int z) { return y == 63 && ((x * 31 + z * 17) & 15) == 5 ? 1 : 0; }
    }

    public static void main(String[] args) throws Exception {
        for (long seed : new long[] {0, 1, -1, 123456789L}) {
            SpawnWorld world = new SpawnWorld(seed);
            OriginalProvider provider = new OriginalProvider(world, seed);
            set(world, "v", provider);
            world.r = new Random(12345);
            world.initial();
            br spawn = world.u();
            long state = world.r.nextLong();
            SpawnPlayer player = new SpawnPlayer(world);
            player.t_();
            System.out.printf("spawn %d %d %d %d random%d feet%.17g,%.17g,%.17g eye%.17g chunks%d%n",
                seed, spawn.a, spawn.b, spawn.c, state, player.aM, player.aN - player.bf, player.aO,
                player.aN, provider.chunks.size());
            world.x().a(0, 0, 0);
            world.r = new Random(54321);
            world.d();
            spawn = world.u();
            System.out.printf("spawn-adjust %d %d %d %d random%d%n", seed, spawn.a, spawn.b, spawn.c, world.r.nextLong());
        }
        SparseWorld sparse = new SparseWorld();
        sparse.x().a(-20, -1, 30);
        sparse.r = new Random(54321);
        sparse.d();
        br spawn = sparse.u();
        System.out.printf("spawn-adjust-sparse %d %d %d random%d%n", spawn.a, spawn.b, spawn.c, sparse.r.nextLong());
    }
}
