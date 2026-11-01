import java.io.File;
import java.nio.file.Files;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;

/** Calls the original Beta weather tick, daylight, and precipitation predicates. */
public final class WeatherParity {
    private static final class Provider implements cl {
        final fd world;
        final Map<Long, lm> chunks = new HashMap<>();
        int floor, metadata, light;
        Provider(fd world) { this.world = world; }
        public boolean a(int x, int z) { return true; }
        public lm b(int x, int z) {
            return chunks.computeIfAbsent(((long)x << 32) ^ (z & 0xffffffffL), ignored -> {
                lm chunk = new lm(world, new byte[32768], x, z);
                for (int bx = 0; bx < 16; bx++) for (int bz = 0; bz < 16; bz++) {
                    chunk.b[(bx << 11) | (bz << 7) | 64] = (byte)floor;
                    chunk.e.a(bx, 64, bz, metadata);
                }
                java.util.Arrays.fill(chunk.g.a, (byte)(light | (light << 4)));
                return chunk;
            });
        }
        public lm c(int x, int z) { return b(x, z); }
        public void a(cl provider, int x, int z) {}
        public boolean a(boolean all, yb progress) { return true; }
        public boolean a() { return false; }
        public boolean b() { return false; }
        public String c() { return "WeatherParity"; }
    }

    private static final class World extends fd {
        World(File directory, long seed, boolean nether) {
            super(new fm(directory, "save", false), "WeatherParity", nether ? new wd() : new rh(), seed);
        }
        @Override protected cl b() { return new Provider(this); }
        void configure(boolean rain, boolean thunder, int rainTime, int thunderTime, long seed) {
            x.b(rain); x.a(thunder); x.f(rainTime); x.e(thunderTime);
            i = k = 0; j = rain ? 1 : 0; l = rain && thunder ? 1 : 0;
            r = new Random(seed);
        }
        void tickWeather() { m(); }
        void tickPrecipitation() { n(); }
        String state() {
            return (x.o() ? 1 : 0) + " " + (x.m() ? 1 : 0) + " " + x.p() + " " + x.n()
                + " " + Integer.toHexString(Float.floatToRawIntBits(j))
                + " " + Integer.toHexString(Float.floatToRawIntBits(l));
        }
        void steady(float rain, float thunder) { i = j = rain; k = l = thunder; }
    }

    private static void snow(File directory, String name, int floor, int metadata, int light, boolean raining) throws Exception {
        World world = new World(directory, 11, false);
        world.configure(raining, false, 1000, 1000, 0);
        Provider provider = (Provider)world.w();
        provider.floor = floor; provider.metadata = metadata; provider.light = light;
        world.t.b = new hd(kd.g, 0.3, 0.9);
        world.r = new Random(0) { @Override public int nextInt(int bound) {
            return bound == 16 ? 0 : bound == 100000 ? 1 : super.nextInt(bound);
        }};
        java.lang.reflect.Field cooldown = fd.class.getDeclaredField("Q");
        cooldown.setAccessible(true); cooldown.setInt(world, 10000);
        gs player = new gs(world) { @Override public void v() {} };
        player.aM = player.aO = 0;
        world.d.add(player);
        world.tickPrecipitation();
        int snow = 0, ice = 0;
        for (lm chunk : provider.chunks.values()) for (byte value : chunk.b) {
            if ((value & 255) == 78) snow++;
            if ((value & 255) == 79) ice++;
        }
        System.out.println("snow " + name + " " + snow + " " + ice);
    }

    private static void trace(File directory, String name, long seed, boolean rain, boolean thunder,
                              int rainTime, int thunderTime, boolean nether, int count) {
        World world = new World(directory, seed, nether);
        world.configure(rain, thunder, rainTime, thunderTime, seed);
        for (int tick = 1; tick <= count; tick++) {
            world.tickWeather();
            if (tick <= 2 || tick == 50 || tick == 99 || tick == 100 || tick == 101 || tick == count)
                System.out.println(name + " " + tick + " " + world.state());
        }
        System.out.println(name + " rng " + world.r.nextInt());
    }

    public static void main(String[] args) throws Exception {
        Class.forName("uu");
        File directory = args.length == 0 ? Files.createTempDirectory("beta-weather-").toFile() : new File(args[0]);
        directory.mkdirs();
        trace(directory, "dry", 0, false, false, 0, 0, false, 6);
        trace(directory, "start", 123456789, false, false, 1, 1, false, 200);
        trace(directory, "end", 42, true, true, 1, 2, false, 101);
        trace(directory, "nether", 42, true, true, 1, 2, true, 101);
        World world = new World(directory, 0, false);
        for (float strength : new float[]{0, 0.5f, 1}) {
            world.steady(strength, strength);
            for (long time : new long[]{0, 6000, 12000, 13000, 18000, 23000, -1}) {
                world.a(time);
                for (float partial : new float[]{0, 0.5f, 1})
                    System.out.println("day " + strength + " " + time + " " + partial + " "
                        + Integer.toHexString(Float.floatToRawIntBits(world.b(partial))) + " " + world.a(partial));
            }
        }
        for (double[] climate : new double[][]{{0.05,0.5},{0.4,0.9},{1,0},{0.7,0.5},{1,1}}) {
            kd biome = kd.a(climate[0], climate[1]);
            System.out.println("biome " + climate[0] + " " + climate[1] + " " + biome.n + " " + biome.c() + " " + biome.d());
        }
        for (long seed = 0; seed < 100; seed++) {
            World cold = new World(directory, seed, false);
            if (cold.a().a(0,0).c()) { System.out.println("cold-seed " + seed); break; }
        }
        world.steady(1,1);
        lm chunk = world.c(0,0);
        for (int[] p : new int[][]{{4,64,4,1},{8,64,8,18},{12,64,12,9},{4,70,4,1}})
            chunk.b[(p[0]<<11)|(p[2]<<7)|p[1]] = (byte)p[3];
        chunk.c();
        for (int[] p : new int[][]{{4,65,4},{4,71,4},{8,65,8},{12,65,12},{1,64,1}})
            System.out.println("exposure " + p[0] + " " + p[1] + " " + p[2] + " " + world.e(p[0],p[2]) + " " + world.t(p[0],p[1],p[2]));
        for (float rain : new float[]{Math.nextDown(0.2f),0.2f}) {
            world.steady(rain,1);
            System.out.println("rain-threshold " + Integer.toHexString(Float.floatToRawIntBits(rain)) + " " + world.C());
        }
        world.steady(1,1);
        System.out.println("void-lightning " + world.t(1,-1,1));
        snow(directory, "stone-rain", 1, 0, 0, true);
        snow(directory, "leaves-rain", 18, 0, 0, true);
        snow(directory, "water-clear", 9, 0, 0, false);
        snow(directory, "water-metadata", 9, 1, 0, true);
        snow(directory, "water-light10", 9, 0, 10, true);
        snow(directory, "stone-light9", 1, 0, 9, true);
        snow(directory, "stone-light10", 1, 0, 10, true);
    }
}
