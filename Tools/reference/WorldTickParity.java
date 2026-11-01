import java.util.AbstractSet;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.Random;
import java.util.ArrayList;
import java.util.List;

// Compile against the original client and a renamed, otherwise unchanged OpenJDK6 HashMap.
// Source: https://github.com/openjdk/jdk6/blob/master/jdk/src/share/classes/java/util/HashMap.java
// LegacyHashMap.java stays under ignored .build/reference; only package-access/serialization glue is adapted.
public class WorldTickParity extends TerrainParity {
    static class LegacySet<E> extends AbstractSet<E> {
        final LegacyHashMap<E, Boolean> values = new LegacyHashMap<>();
        public boolean add(E value) { return values.put(value, true) == null; }
        public int size() { return values.size(); }
        public Iterator<E> iterator() { return values.keySet().iterator(); }
        public void clear() { values.clear(); }
    }
    static class Provider implements cl {
        final fd world;
        final Map<Long, lm> chunks = new HashMap<>();
        boolean dark;
        Provider(fd world) { this.world = world; }
        public boolean a(int x, int z) { return chunks.containsKey(chunkKey(x, z)); }
        public lm b(int x, int z) { return c(x, z); }
        public lm c(int x, int z) {
            long key = chunkKey(x, z);
            if (chunks.containsKey(key)) { return chunks.get(key); }
            lm chunk = new lm(world, new byte[32768], x, z);
            if (!dark) {
                Arrays.fill(chunk.f.a, (byte)255);
                for (int bx = 0; bx < 16; bx++) for (int bz = 0; bz < 16; bz++) {
                    chunk.b[bx << 11 | bz << 7 | 64] = 2;
                }
            }
            chunks.put(key, chunk);
            return chunk;
        }
        public void a(cl provider, int x, int z) {}
        public boolean a(boolean save, yb progress) { return true; }
        public boolean a() { return false; }
        public boolean b() { return true; }
        public String c() { return "WorldTickParity"; }
    }
    static class World extends fd {
        float cavePitch;
        World(boolean hell) { super(new MemorySaveHandler(), "Tick parity", hell ? new wd() : new rh(), 0); }
        void tickEnvironment() { m(); n(); }
        int lcg() { return g; }
        void lcg(int value) { g = value; }
        public void a(double x, double y, double z, String name, float volume, float pitch) {
            if (name.equals("ambient.cave.cave")) { cavePitch = pitch; }
        }
    }
    static class Player extends gs {
        Player(fd world) { super(world); }
        public void v() {}
    }
    static class Probe extends uu {
        final List<Integer> ticks = new ArrayList<>();
        boolean inserted;
        Probe() { super(97, ln.c); }
        public void a(fd world, int x, int y, int z, Random random) {
            ticks.add(x);
            if (x == 8 && !inserted) { inserted = true; world.c(11, y, z, 97, 0); }
        }
    }
    static class NotificationProbe extends uu {
        static final List<String> trace = new ArrayList<>();
        static boolean nested;
        NotificationProbe(int id) { super(id, ln.c); }
        String at(int x, int y, int z) { return bn + "@" + x + "," + y + "," + z; }
        public void c(fd world, int x, int y, int z) { trace.add("add:" + at(x, y, z)); }
        public void b(fd world, int x, int y, int z) { trace.add("remove:" + at(x, y, z)); }
        public void b(fd world, int x, int y, int z, int changed) {
            trace.add("neighbor:" + at(x, y, z) + "<-" + changed);
            if (bn == 98 && x == 7 && y == 10 && z == 8 && !nested) {
                nested = true;
                world.f(6, 10, 8, 99);
            }
        }
    }
    static long orderHash(Iterable<yy> values) {
        long hash = 0xcbf29ce484222325L;
        for (yy p : values) {
            hash = (hash ^ (p.a & 0xffffffffL)) * 0x100000001b3L;
            hash = (hash ^ (p.b & 0xffffffffL)) * 0x100000001b3L;
        }
        return hash;
    }
    public static void main(String[] args) throws Exception {
        int bootstrap = uu.u.bn;
        System.out.print("random-tick-kinds");
        for (int id = 0; id <= 96; id++) { if (uu.n[id]) System.out.print(" " + id); }
        System.out.println();
        for (boolean hell : new boolean[] {false, true}) {
            World world = new World(hell);
            Provider provider = new Provider(world);
            set(world, "v", provider);
            LegacySet<yy> active = new LegacySet<>();
            set(world, "P", active);
            set(world, "Q", 10000);
            world.r = new Random(42);
            world.lcg(0x12345678);
            world.x().f(1000); world.x().e(1000);
            Player player = new Player(world);
            player.e(8.5, 65 + (double)player.bf, 8.5);
            world.d.add(player);
            for (int tick = 1; tick <= 3; tick++) {
                world.tickEnvironment();
                System.out.printf("tick %s %d order%016x lcg%d next%d%n", hell ? "nether" : "overworld", tick,
                    orderHash(active), world.lcg(), world.r.nextInt());
            }
        }
        LegacySet<yy> set = new LegacySet<>();
        for (int pass = 0; pass < 3; pass++) {
            set.clear();
            for (int[] center : new int[][] {{pass - 2, -pass}, {0, 0}}) {
                for (int x = -9; x <= 9; x++) for (int z = -9; z <= 9; z++) set.add(new yy(center[0] + x, center[1] + z));
            }
            System.out.printf("active %d count%d hash%016x%n", pass, set.size(), orderHash(set));
        }
        World darkWorld = new World(false);
        Provider darkProvider = new Provider(darkWorld); darkProvider.dark = true;
        set(darkWorld, "v", darkProvider); set(darkWorld, "P", new LegacySet<yy>()); set(darkWorld, "Q", 0);
        darkWorld.r = new Random(42); darkWorld.lcg(0x12345678);
        darkWorld.x().f(1000); darkWorld.x().e(1000);
        Player darkPlayer = new Player(darkWorld); darkPlayer.e(8.5, 65 + (double)darkPlayer.bf, 8.5); darkWorld.d.add(darkPlayer);
        java.lang.reflect.Field cooldown = fd.class.getDeclaredField("Q"); cooldown.setAccessible(true);
        for (int tick = 1; tick <= 3; tick++) {
            darkWorld.tickEnvironment();
            System.out.printf("ambient %d lcg%d cooldown%d next%d%n", tick, darkWorld.lcg(), cooldown.getInt(darkWorld), darkWorld.r.nextInt());
        }
        darkWorld.d.clear(); darkWorld.d.add(darkPlayer);
        set(darkWorld, "P", new LegacySet<yy>() { public boolean add(yy p) { return p.a == 0 && p.b == 0 && super.add(p); } });
        set(darkWorld, "Q", 0); darkWorld.r = new Random(42); darkWorld.lcg(1099108075);
        darkWorld.tickEnvironment();
        System.out.printf("ambient-cave lcg%d cooldown%d pitchbits%08x next%d%n", darkWorld.lcg(), cooldown.getInt(darkWorld),
            Float.floatToIntBits(darkWorld.cavePitch), darkWorld.r.nextInt());
        Probe probe = new Probe();
        World scheduled = new World(false);
        Provider provider = new Provider(scheduled);
        set(scheduled, "v", provider);
        for (int x = -1; x <= 1; x++) for (int z = -1; z <= 1; z++) provider.c(x, z);
        for (int x = 8; x <= 11; x++) provider.b(0, 0).b[x << 11 | 8 << 7 | 10] = 97;
        scheduled.a(100L);
        scheduled.c(8, 10, 8, 97, 0);
        scheduled.c(8, 10, 8, 97, -10);
        scheduled.c(9, 10, 8, 97, 0);
        scheduled.c(10, 10, 8, 97, 5);
        System.out.println("scheduled-first remaining" + scheduled.a(false) + " ticks" + probe.ticks);
        scheduled.a(105L);
        System.out.println("scheduled-second remaining" + scheduled.a(false) + " ticks" + probe.ticks);
        probe.ticks.clear();
        scheduled.c(8, 10, 8, 97, 0);
        provider.chunks.remove(chunkKey(1, 0));
        System.out.println("scheduled-unloaded remaining" + scheduled.a(false) + " ticks" + probe.ticks);
        scheduled.c(8, 10, 8, 97, 0);
        System.out.println("scheduled-request-unloaded remaining" + scheduled.a(false) + " ticks" + probe.ticks);
        for (int x = 0; x <= 1; x++) for (int z = 0; z <= 5; z++) provider.c(x, z);
        for (int i = 0; i < 1001; i++) {
            int x = 8 + i % 16, z = 8 + i / 16;
            provider.b(x >> 4, z >> 4).b[(x & 15) << 11 | (z & 15) << 7 | 10] = 97;
            scheduled.c(x, 10, z, 97, 100);
        }
        System.out.println("scheduled-future remaining" + scheduled.a(false) + " count" + probe.ticks.size());
        System.out.println("scheduled-forced remaining" + scheduled.a(true) + " count" + probe.ticks.size());
        System.out.println("scheduled-forced-rest remaining" + scheduled.a(true) + " count" + probe.ticks.size());
        new NotificationProbe(98); new NotificationProbe(99);
        World notifications = new World(false);
        Provider notificationProvider = new Provider(notifications); set(notifications, "v", notificationProvider);
        lm notificationChunk = notificationProvider.c(0, 0);
        for (int[] p : new int[][] {{7,10,8},{9,10,8},{8,9,8},{8,11,8},{8,10,7},{8,10,9},{6,10,8}}) {
            notificationChunk.b[p[0] << 11 | p[2] << 7 | p[1]] = 98;
        }
        notifications.f(8, 10, 8, 99);
        System.out.println("notify-replace " + NotificationProbe.trace);
        NotificationProbe.trace.clear();
        notifications.d(8, 10, 8, 1);
        System.out.println("notify-metadata " + NotificationProbe.trace);
        NotificationProbe.trace.clear();
        notifications.b(8, 10, 8, 99, 2);
        System.out.println("notify-id-metadata " + NotificationProbe.trace);
    }
}
