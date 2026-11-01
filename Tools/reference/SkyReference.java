import java.lang.reflect.Field;
import sun.misc.Unsafe;

/** Records sky, cloud, and sunrise colors by calling the original client methods. */
public final class SkyReference {
    static final class Climate extends xv {
        double temperature;
        public double b(int x,int z) { return temperature; }
        public kd a(int x,int z) { return kd.c; }
    }
    static final class World extends fd {
        long time;
        float rain, thunder;
        Climate climate;
        World() { super((wt)null,"SkyReference",0L); }
        public xv a() { return climate; }
        public float b(float partial) { return t.a(time,partial); }
        public float g(float partial) { return rain; }
        public float f(float partial) { return thunder; }
    }
    static final class Entity extends gs {
        Entity(fd world) { super(world); }
        public void v() {}
    }
    static int bits(float value) { return Float.floatToRawIntBits(value); }
    static void vector(bt value) {
        System.out.print("["+bits((float)value.a)+","+bits((float)value.b)+","+bits((float)value.c)+"]");
    }
    public static void main(String[] args) throws Exception {
        java.io.PrintStream output = System.out;
        System.setOut(new java.io.PrintStream(new java.io.ByteArrayOutputStream()));
        Class.forName("uu");
        Field field=Unsafe.class.getDeclaredField("theUnsafe"); field.setAccessible(true);
        Unsafe unsafe=(Unsafe)field.get(null);
        World world=(World)unsafe.allocateInstance(World.class);
        Entity entity=(Entity)unsafe.allocateInstance(Entity.class);
        Field provider=fd.class.getDeclaredField("t"); provider.setAccessible(true); provider.set(world,xa.a(0));
        Field cloud=fd.class.getDeclaredField("H"); cloud.setAccessible(true); cloud.setLong(world,0xffffff);
        world.climate=new Climate();
        System.setOut(output);
        System.out.println("[");
        boolean first=true;
        for(long time:new long[]{0,6000,12000,12500,13000,18000,23000,23500})
        for(float partial:new float[]{0,.5f,1})
        for(float temperature:new float[]{.1f,.5f,1})
        for(float storm:new float[]{0,.5f,1}) {
            world.time=time; world.rain=storm; world.thunder=storm*storm; world.climate.temperature=temperature;
            if(!first)System.out.println(","); first=false;
            float angle=world.b(partial);
            System.out.print("{\"time\":"+time+",\"partial\":"+partial+",\"temperature\":"+temperature+",\"rain\":"+storm+",\"thunder\":"+world.thunder+",\"angle\":"+bits(angle)+",\"sky\":");
            vector(world.a(entity,partial)); System.out.print(",\"fog\":");vector(world.d(partial));
            System.out.print(",\"cloud\":");vector(world.c(partial));
            System.out.print(",\"stars\":"+bits(world.e(partial)*(1-storm))+",\"subtraction\":"+world.a(partial)+",\"sunrise\":");
            float[] sunrise=world.t.a(angle,partial);
            if(sunrise==null)System.out.print("null");
            else System.out.print("["+bits(sunrise[0])+","+bits(sunrise[1])+","+bits(sunrise[2])+","+bits(sunrise[3])+"]");
            System.out.print("}");
        }
        System.out.println("\n]");
    }
}
