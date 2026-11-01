import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.AbstractSet;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Random;
import sun.misc.Unsafe;

/** Runs the original wire method with Java 6 collection order and a small in-memory world. */
public final class WireParity {
    private static Unsafe unsafe;

    private static final class Java6Set extends AbstractSet<wf> {
        private List<List<wf>> buckets = buckets(16);
        private int size;

        private static List<List<wf>> buckets(int count) {
            List<List<wf>> result = new ArrayList<>();
            for (int i = 0; i < count; i++) result.add(new ArrayList<>());
            return result;
        }

        private int hash(wf value) {
            int h = value.hashCode();
            h ^= (h >>> 20) ^ (h >>> 12);
            return h ^ (h >>> 7) ^ (h >>> 4);
        }

        @Override public boolean add(wf value) {
            List<wf> bucket = buckets.get(hash(value) & (buckets.size() - 1));
            if (bucket.contains(value)) return false;
            bucket.add(0, value);
            if (++size > buckets.size() * 3 / 4) {
                List<List<wf>> expanded = buckets(buckets.size() * 2);
                for (List<wf> previous : buckets) {
                    for (wf entry : previous) expanded.get(hash(entry) & (expanded.size() - 1)).add(0, entry);
                }
                buckets = expanded;
            }
            return true;
        }

        @Override public int size() { return size; }
        @Override public void clear() { for (List<wf> bucket : buckets) bucket.clear(); size = 0; }
        @Override public Iterator<wf> iterator() {
            List<wf> result = new ArrayList<>();
            for (List<wf> bucket : buckets) result.addAll(bucket);
            return result.iterator();
        }
    }

    private static final class World extends fd {
        Map<String, int[]> blocks;
        List<int[]> writes, notifications;
        List<long[]> scheduled;
        boolean callbacks;
        long time;

        private World() { super((wt) null, "wire-oracle", 0L); }
        String key(int x, int y, int z) { return x + "," + y + "," + z; }
        void raw(int x, int y, int z, int id, int data) { blocks.put(key(x, y, z), new int[]{id, data}); }
        @Override public int a(int x, int y, int z) { int[] value = blocks.get(key(x, y, z)); return value == null ? 0 : value[0]; }
        @Override public int e(int x, int y, int z) { int[] value = blocks.get(key(x, y, z)); return value == null ? 0 : value[1]; }
        @Override public ln f(int x, int y, int z) { int id = a(x, y, z); return id == 0 ? ln.a : uu.m[id].bA; }
        @Override public boolean h(int x, int y, int z) { int id = a(x, y, z); return id != 0 && uu.m[id].bA.h() && uu.m[id].d(); }
        @Override public boolean s(int x, int y, int z) {
            return k(x, y - 1, z, 0) || k(x, y + 1, z, 1) || k(x, y, z - 1, 2)
                || k(x, y, z + 1, 3) || k(x - 1, y, z, 4) || k(x + 1, y, z, 5);
        }
        @Override public void d(int x, int y, int z, int data) {
            int id = a(x, y, z);
            raw(x, y, z, id, data);
            writes.add(new int[]{x, y, z, data});
            if (callbacks && !o) i(x, y, z, id);
        }
        @Override public boolean b(int x, int y, int z, int id, int data) {
            int previous = a(x, y, z), metadata = e(x, y, z);
            if (previous == id && metadata == data) return false;
            raw(x, y, z, id, metadata);
            if (previous != 0) uu.m[previous].b(this, x, y, z);
            raw(x, y, z, id, data);
            if (id != 0) uu.m[id].c(this, x, y, z);
            i(x, y, z, id);
            return true;
        }
        @Override public void i(int x, int y, int z, int id) {
            notifications.add(new int[]{x, y, z});
            if (!callbacks || o || B) return;
            int[][] offsets = {{-1,0,0},{1,0,0},{0,-1,0},{0,1,0},{0,0,-1},{0,0,1}};
            for (int[] offset : offsets) {
                int nx = x + offset[0], ny = y + offset[1], nz = z + offset[2], neighbor = a(nx, ny, nz);
                if (neighbor != 0) uu.m[neighbor].b(this, nx, ny, nz, id);
            }
        }
        @Override public void b(int x, int y, int z, int xx, int yy, int zz) {}
        @Override public void c(int x, int y, int z, int id, int delay) {
            for (long[] entry : scheduled) {
                if (entry[0] == x && entry[1] == y && entry[2] == z && entry[3] == id) return;
            }
            scheduled.add(new long[]{x, y, z, id, time + delay});
        }
        @Override public long t() { return time; }
    }

    private static World world() throws Exception {
        World world = (World) unsafe.allocateInstance(World.class);
        world.blocks = new HashMap<>();
        world.writes = new ArrayList<>();
        world.notifications = new ArrayList<>();
        world.scheduled = new ArrayList<>();
        world.r = new Random(1);
        for (int x = 2; x < 16; x++) for (int z = 2; z < 16; z++) world.raw(x, 0, z, 1, 0);
        return world;
    }

    private static long hash(List<int[]> trace) {
        long result = 0xcbf29ce484222325L;
        for (int[] row : trace) for (int value : row) for (int i = 0; i < 4; i++) {
            result ^= (value >>> (i * 8)) & 255;
            result *= 0x100000001b3L;
        }
        return result;
    }

    private static void printPulse(World world) {
        System.out.print("tick=" + world.time + " wire=" + world.e(8, 1, 8) + " repeater=" + world.a(9, 1, 8) + " pending=");
        for (long[] entry : world.scheduled) System.out.print(Arrays.toString(entry));
        System.out.println();
    }

    public static void main(String[] args) throws Exception {
        Class.forName("uu");
        Class.forName("gm");
        Field access = Unsafe.class.getDeclaredField("theUnsafe");
        access.setAccessible(true);
        unsafe = (Unsafe) access.get(null);
        Field pending = sm.class.getDeclaredField("b");
        pending.setAccessible(true);
        pending.set(uu.m[55], new Java6Set());
        Method update = sm.class.getDeclaredMethod("h", fd.class, int.class, int.class, int.class);
        update.setAccessible(true);
        for (int scenario = 0; scenario < 4; scenario++) {
            World world = world();
            for (int x = 8; x <= 11; x++) world.raw(x, 1, 8, 55, scenario == 0 ? 0 : 23 - x);
            if (scenario == 0) world.raw(7, 1, 8, 69, 13);
            if (scenario == 2) world.raw(8, 1, 8, 0, 15);
            if (scenario == 3) for (int x = 9; x <= 11; x++) world.raw(x, 1, 9, 55, 22 - x);
            update.invoke(uu.m[55], world, 8, 1, 8);
            System.out.printf("case=%d writes=%d/%016x notifications=%d/%016x%n", scenario,
                world.writes.size(), hash(world.writes), world.notifications.size(), hash(world.notifications));
        }
        pending.set(uu.m[55], new Java6Set());
        World world = world();
        world.callbacks = true;
        world.raw(7, 1, 8, 69, 13);
        world.raw(8, 1, 8, 55, 0);
        world.raw(9, 1, 8, 93, 1);
        world.i(7, 1, 8, 69);
        printPulse(world);
        world.time = 1;
        world.raw(7, 1, 8, 69, 5);
        world.i(7, 1, 8, 69);
        printPulse(world);
        for (int tick = 2; tick <= 4; tick++) {
            world.time = tick;
            List<long[]> due = new ArrayList<>();
            Iterator<long[]> iterator = world.scheduled.iterator();
            while (iterator.hasNext()) {
                long[] entry = iterator.next();
                if (entry[4] <= tick) { due.add(entry); iterator.remove(); }
            }
            for (long[] entry : due) {
                int x = (int) entry[0], y = (int) entry[1], z = (int) entry[2], id = (int) entry[3];
                if (world.a(x, y, z) == id) uu.m[id].a(world, x, y, z, world.r);
            }
            printPulse(world);
        }
    }
}
