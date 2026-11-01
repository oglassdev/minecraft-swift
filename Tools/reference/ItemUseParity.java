import java.util.HashMap;
import java.util.Map;
import java.util.Random;
import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.util.Base64;

// Invokes original Beta item and map code from the locally downloaded client jar.
// Compile alongside TerrainParity.java; no original game implementation is included here.
public class ItemUseParity extends TerrainParity {
    static class ActionPlayer extends gs {
        ActionPlayer(fd world) { super(world); }
        public void v() {}
    }
    static class ActionWorld extends fd {
        sn spawned;
        float volume, pitch;
        boolean target;
        ActionWorld() { super(new MemorySaveHandler(), "Item parity", new rh(), 0); }
        public boolean b(sn entity) { spawned = entity; return true; }
        public void a(sn entity, String sound, float volume, float pitch) { this.volume = volume; this.pitch = pitch; }
        public int a(int x, int y, int z) { return target && x == 0 && y == 66 && z == -5 ? 1 : 0; }
        public int e(int x, int y, int z) { return 0; }
    }
    static class MapProvider implements cl {
        final fd world;
        final Map<Long, lm> chunks = new HashMap<>();
        MapProvider(fd world) { this.world = world; }
        public boolean a(int x, int z) { return chunks.containsKey(chunkKey(x, z)); }
        public lm b(int x, int z) { return c(x, z); }
        public lm c(int cx, int cz) {
            long key = chunkKey(cx, cz);
            if (chunks.containsKey(key)) { return chunks.get(key); }
            byte[] blocks = new byte[32768];
            for (int x = 0; x < 16; x++) {
                for (int z = 0; z < 16; z++) {
                    int wx = cx * 16 + x, wz = cz * 16 + z;
                    int height = 60 + Math.floorMod(wx * 3 + wz * 5, 13);
                    for (int y = 0; y <= Math.max(64, height); y++) {
                        int id = y < height ? 1 : (y == height ? (height < 64 ? 12 : 2) : 9);
                        blocks[x << 11 | z << 7 | y] = (byte) id;
                    }
                }
            }
            lm chunk = new lm(world, blocks, cx, cz);
            chunks.put(key, chunk);
            chunk.c();
            return chunk;
        }
        public void a(cl provider, int x, int z) {}
        public boolean a(boolean save, yb progress) { return true; }
        public boolean a() { return false; }
        public boolean b() { return true; }
        public String c() { return "Map fixture provider"; }
    }

    public static void main(String[] args) throws Exception {
        fd world = world(0);
        int bootstrap = uu.u.bn;
        System.out.print("map-material-colors");
        for (int id = 0; id <= 96; id++) { System.out.print(" " + (id == 0 ? 0 : uu.m[id].bA.C.q)); }
        System.out.println();
        System.out.print("map-opacity");
        for (int id = 0; id <= 96; id++) { System.out.print(" " + uu.q[id]); }
        System.out.println();
        wr item = (wr) gm.c[358];
        for (boolean hell : new boolean[] {false, true}) {
            fd fixture = hell ? new fd(new MemorySaveHandler(), "Map parity", new wd(), 0) : world(0);
            set(fixture, "v", new MapProvider(fixture));
            qw entity = new qw(fixture);
            entity.e(-3.75, 65, 7.25);
            for (byte scale : new byte[] {0, 3, 4}) {
                iu map = new iu("map_0");
                map.b = -13; map.c = 21; map.d = (byte) (hell ? -1 : 0); map.e = scale;
                for (int tick = 0; tick < 16; tick++) { item.a(fixture, entity, map); }
                System.out.printf("map %s scale%d %016x %d%n", hell ? "nether" : "overworld", scale, hash(map.f), map.g);
            }
        }
        java.lang.reflect.Field itemRandom = gm.class.getDeclaredField("b");
        itemRandom.setAccessible(true);
        itemRandom.set(null, new Random(123456789L));
        ActionWorld actionWorld = new ActionWorld();
        ActionPlayer player = new ActionPlayer(actionWorld);
        player.e(2, 65 + (double) player.bf, -3);
        player.aS = 180; player.aT = 0;
        player.c.a[5] = new iz(262, 2, 0);
        for (int id : new int[] {261, 332, 344, 346}) {
            iz stack = new iz(id, id == 332 || id == 344 ? 2 : 1, 0);
            gm.c[id].a(stack, actionWorld, player);
            sn entity = actionWorld.spawned;
            System.out.printf("item %d count%d arrows%d volume%.9g pitch%.9g origin%.17g,%.17g,%.17g%n",
                id, stack.a, player.c.a[5].a, actionWorld.volume, actionWorld.pitch,
                entity.aM, entity.aN, entity.aO);
        }
        player.e(.5, 65 + (double) player.bf, -2.5);
        player.Y = 20;
        iz food = new iz(260, 1, 0);
        gm.c[260].a(food, actionWorld, player);
        System.out.println("food-full count" + food.a + " health" + player.Y);
        System.out.println("milk-air " + gm.c[335].a(new iz(335, 1, 0), actionWorld, player).c);
        actionWorld.target = true;
        System.out.println("milk-block " + gm.c[335].a(new iz(335, 1, 0), actionWorld, player).c);
        iu saved = new iu("map_7");
        saved.b = -31; saved.c = 25; saved.d = -1; saved.e = 3; saved.f[0] = 51;
        nu fields = new nu(); saved.b(fields);
        nu root = new nu(); root.a("data", fields);
        ByteArrayOutputStream encoded = new ByteArrayOutputStream();
        as.a(root, encoded);
        System.out.println("map-nbt " + Base64.getEncoder().encodeToString(encoded.toByteArray()));
        nu counts = new nu(); counts.a("map", (short)7); counts.a("other", (short)99);
        encoded = new ByteArrayOutputStream();
        as.a(counts, (java.io.DataOutput)new DataOutputStream(encoded));
        System.out.println("map-counts " + Base64.getEncoder().encodeToString(encoded.toByteArray()));
    }
}
