public class BlockLightReference {
    public static void main(String[] args) throws Exception {
        Class<?> block = Class.forName("uu");
        int[] opacity = (int[])block.getField("q").get(null);
        int[] emission = (int[])block.getField("s").get(null);
        for (int id = 0; id <= 96; id++) System.out.println(id + "\t" + opacity[id] + "\t" + emission[id]);
    }
}
