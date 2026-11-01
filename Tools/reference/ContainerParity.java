// Compile with TerrainParity.java and ItemUseParity.java against the local original client jar.
public class ContainerParity extends ItemUseParity {
    static String stack(iz s) { return s == null ? "-" : s.c+":"+s.a+":"+s.i(); }
    public static void main(String[] args) {
        ActionWorld w = new ActionWorld();
        int bootstrap = uu.u.bn;
        ActionPlayer p = new ActionPlayer(w);
        aa c = new aa(p.c);
        p.c.a[0] = new iz(35,60,4); p.c.b(new iz(35,6,5));
        c.a(36,1,false,p);
        System.out.println("swap "+stack(p.c.a[0])+" "+stack(p.c.i()));
        p.c.a[0] = new iz(267,1,2); p.c.b(new iz(267,1,3));
        c.a(36,1,false,p);
        System.out.println("swords "+stack(p.c.a[0])+" "+stack(p.c.i()));
        for(int i=0;i<36;i++) p.c.a[i]=new iz(1,64,0);
        p.c.a[8]=new iz(5,63,0); p.c.b((iz)null);
        c.a.a(0,new iz(17,2,0));
        c.a(0,0,true,p);
        System.out.println("partial "+stack(p.c.a[8])+" "+stack(c.a.f_(0))+" "+stack(c.b.f_(0)));
        cu f = new cu();
        System.out.print("mouse");
        for(float delta:new float[]{8,0,0,-4,0,12,0,0}) System.out.print(" "+Integer.toUnsignedString(Float.floatToRawIntBits(f.a(delta,.05F))));
        System.out.println();
        p = new ActionPlayer(w); p.J();
        System.out.print("swing");
        for(int i=0;i<10;i++) {p.f_();System.out.print(" "+Integer.toUnsignedString(Float.floatToRawIntBits(p.X)));}
        System.out.println();
        p = new ActionPlayer(w); p.Y=20; p.a((sn)null,4);
        System.out.println("hurt "+p.Y+" "+p.Z+" "+p.aa+" "+p.ab+" "+p.by);
    }
}
