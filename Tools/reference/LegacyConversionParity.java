import java.io.*;
import java.nio.file.Files;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.HexFormat;

/** Generates Alpha fixtures and exercises the original McRegion converter/reader. */
public final class LegacyConversionParity {
    private static nu chunk(int x, int z, String label) {
        nu root = new nu(), level = new nu(); root.a("Level", level); root.a("UnknownRoot", "retain-" + label);
        level.a("xPos", x); level.a("zPos", z); level.a("LastUpdate", 12345L);
        byte[] blocks = new byte[32768]; blocks[321] = (byte)250;
        level.a("Blocks", blocks); level.a("Data", new byte[16384]);
        level.a("SkyLight", new byte[16384]); level.a("BlockLight", new byte[16384]);
        level.a("HeightMap", new byte[256]); level.a("TerrainPopulated", true);
        sp entities = new sp(); nu entity = new nu(); entity.a("id", "Painting"); entity.a("Motive", "Pointer");
        entity.a("CustomEntity", "unchanged"); entities.a(entity); level.a("Entities", entities);
        sp tiles = new sp(); nu tile = new nu(); tile.a("id", "ModdedTile"); tile.a("CustomBytes", new byte[]{0,127,(byte)255});
        tiles.a(tile); level.a("TileEntities", tiles); level.a("UnknownChunk", label);
        return root;
    }
    private static byte[] bytes(nu root) throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream(); ij.a(root, new DataOutputStream(bytes)); return bytes.toByteArray();
    }
    private static File legacy(File world, int x, int z) {
        return new File(new File(new File(world, Integer.toString(x & 63,36)), Integer.toString(z & 63,36)),
            "c." + Integer.toString(x,36) + "." + Integer.toString(z,36) + ".dat");
    }
    private static void write(File file, nu root) throws IOException {
        file.getParentFile().mkdirs(); as.a(root, new FileOutputStream(file));
    }
    private static void generate(File world) throws Exception {
        nu root = new nu(), data = new nu(); root.a("Data",data); root.a("CustomRoot", "keep level root");
        data.a("RandomSeed",123L); data.a("LevelName", "Legacy fixture"); data.a("version",0);
        data.a("SpawnX",0); data.a("SpawnY",70); data.a("SpawnZ",0); data.a("Time",6000L);
        data.a("CustomLevel", "retain level data");
        write(new File(world,"level.dat"),root);
        write(legacy(world,-33,65),chunk(-33,65,"overworld"));
        write(legacy(new File(world,"DIM-1"),2,-3),chunk(2,-3,"nether"));
    }
    private static void verify(File world) throws Exception {
        for (int dimension : new int[]{0,-1}) {
            File folder = dimension == 0 ? world : new File(world,"DIM-1");
            int x = dimension == 0 ? -33 : 2, z = dimension == 0 ? 65 : -3;
            DataInputStream stream = rj.c(folder,x,z);
            if (stream == null) throw new AssertionError("Missing converted chunk");
            byte[] actual = stream.readAllBytes(); stream.close();
            byte[] expected = bytes(chunk(x,z,dimension == 0 ? "overworld" : "nether"));
            if (!java.util.Arrays.equals(expected,actual)) throw new AssertionError("Raw NBT bytes changed");
            nu decoded = (nu)ij.b(new DataInputStream(new ByteArrayInputStream(actual)));
            if ((decoded.k("Level").j("Blocks")[321] & 255) != 250) throw new AssertionError("Unknown block changed");
            System.out.println("verified " + dimension + " " + x + " " + z + " " + HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(actual)));
        }
        rj.a();
        nu data = as.a(new FileInputStream(new File(world,"level.dat"))).k("Data");
        if (data.e("version") != 19132) throw new AssertionError("Level not upgraded");
    }
    public static void main(String[] args) throws Exception {
        File base = new File(args.length > 1 ? args[1] : ".build/reference/legacy-oracle");
        if (args.length > 0 && args[0].equals("verify")) { verify(base); return; }
        generate(new File(base,"input")); generate(new File(base,"java-converted"));
        hi converter = new hi(base);
        converter.a("java-converted",new yb() {
            public void b(String message) {} public void d(String message) {} public void a(int progress) {}
        });
        verify(new File(base,"java-converted"));
        for (int dimension : new int[]{0,-1}) {
            File folder = dimension == 0 ? new File(base,"input") : new File(base,"input/DIM-1");
            File file = legacy(folder,dimension == 0 ? -33 : 2,dimension == 0 ? 65 : -3);
            System.out.println((dimension == 0 ? "OVERWORLD=" : "NETHER=") + Base64.getEncoder().encodeToString(Files.readAllBytes(file.toPath())));
        }
    }
}
