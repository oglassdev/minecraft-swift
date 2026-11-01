import java.lang.reflect.*;
import java.util.*;
import sun.misc.Unsafe;

// Runs controlled entity vectors against the unmodified Beta 1.7.3 client jar.
public final class EntityParity {
  static final class World extends fd {
    List<sn> bodies = new ArrayList<>();
    Map<String,Integer> rails = new HashMap<>();
    boolean wall;
    World() { super((wt)null, "fixture", 0L); }
    String key(int x,int y,int z) { return x+","+y+","+z; }
    @Override public int a(int x,int y,int z) { return rails.containsKey(key(x,y,z))?66:0; }
    @Override public br u() { return new br(0,64,0); }
    @Override public int e(int x,int y,int z) { return rails.getOrDefault(key(x,y,z),0); }
    @Override public boolean a(int a,int b,int c,int d,int e,int f) { return false; }
    @Override public boolean a(eq box,ln material,sn entity) { return false; }
    @Override public boolean a(eq box,ln material) { return false; }
    @Override public boolean b(eq box,ln material) { return false; }
    @Override public boolean c(eq box) { return false; }
    @Override public List b(sn excluded,eq query) {
      List<sn> found = new ArrayList<>();
      for(sn body:bodies) if(body!=excluded&&!body.be&&body.aW.a(query)) found.add(body);
      return found;
    }
    @Override public List a(sn mover,eq query) {
      List<eq> boxes = new ArrayList<>();
      if(wall) { eq box=eq.b(1,0,-10,2,10,10); if(box.a(query))boxes.add(box); }
      for(Object item:b(mover,query.b(.25,.25,.25))) {
        sn other=(sn)item;
        eq box=other.f();if(box!=null&&box.a(query))boxes.add(box);
        box=mover.a(other);if(box!=null&&box.a(query))boxes.add(box);
      }
      return boxes;
    }
    @Override public gs a(sn entity,double distance) { return null; }
    @Override public void a(sn entity,String name,float volume,float pitch) {}
    @Override public void a(String name,double x,double y,double z,double vx,double vy,double vz) {}
    @Override public void a(sn entity,byte status) {}
    @Override public boolean b(sn entity) { bodies.add(entity);return true; }
  }
  static final class Player extends gs {
    Player(fd world) { super(world); l="Player"; }
    public void v() {}
    public void a(vr statistic,int amount) {}
  }
  static final class Mob extends ls {
    Mob(fd world) { super(world); }
  }
  static World world() throws Exception {
    Field field=Unsafe.class.getDeclaredField("theUnsafe");field.setAccessible(true);
    World world=(World)((Unsafe)field.get(null)).allocateInstance(World.class);
    world.bodies=new ArrayList<>();world.rails=new HashMap<>();world.r=new Random(1234);world.q=2;return world;
  }
  static void collisionVectors() throws Exception {
    for(String kind:new String[]{"boat","cart"}) {
      World world=world();Mob mover=new Mob(world);mover.e(0,1,0);
      sn obstacle=kind.equals("boat")?new fz(world,2,1,0):new yl(world,2,1,0,0);
      world.bodies.add(obstacle);mover.b(2,0,0);
      System.out.printf("clipLiving %s %.17g%n",kind,mover.aM);
    }
    World world=world();yl mover=new yl(world,0,1,0,0);Mob obstacle=new Mob(world);obstacle.e(2,1,0);world.bodies.add(obstacle);mover.b(2,0,0);
    System.out.printf("clipCartLiving %.17g%n",mover.aM);
    for(int furnace=0;furnace<3;furnace++) {
      world=world();yl a=new yl(world,0,1,0,furnace==1?2:0),b=new yl(world,.8,1,.2,furnace==2?2:0);
      a.aP=.3;a.aR=.1;b.aP=-.1;b.aR=-.2;b.aJ=0;a.h(b);
      System.out.printf("cartPush %d %.17g %.17g %.17g %.17g%n",furnace,a.aP,a.aR,b.aP,b.aR);
    }
    world=world();Mob a=new Mob(world),b=new Mob(world);a.e(0,1,0);b.e(.8,1,.2);a.h(b);
    System.out.printf("livingPush %.17g %.17g %.17g %.17g%n",a.aP,a.aR,b.aP,b.aR);
    world=world();yl cart=new yl(world,0,1,0,0);Mob passenger=new Mob(world);passenger.e(.8,1,0);cart.aP=.2;cart.h(passenger);
    System.out.println("pickupLiving "+(cart.aG==passenger)+" "+(passenger.aH==cart));
  }
  static void boatVectors() throws Exception {
    World world=world();fz boat=new fz(world,.5,1,.5);boat.aP=.2;boat.bs=new Random(1234);
    for(int i=1;i<=5;i++) { boat.w_(); System.out.printf("boatAir %d %.17g %.17g %.17g %.17g %.9g%n",i,boat.aM,boat.aN-boat.bf,boat.aP,boat.aQ,boat.aS); }
    world=world();world.wall=true;boat=new fz(world,0,1,0);boat.aP=.3;boat.aR=.3;boat.w_();System.out.printf("boatCrash %s %.17g %.17g drops=%d%n",boat.be,boat.aM,boat.aO,world.bodies.size());
  }
  static void livingVectors() throws Exception {
    World world=world(); Mob mob=new Mob(world);mob.Y=20;mob.e(0,1,0);mob.bs=new Random(1234);mob.bv=40;
    for(int i=1;i<=3;i++){mob.U();System.out.printf("fire %d health=%d fire=%d hurt=%d resistance=%d previous=%d%n",i,mob.Y,mob.bv,mob.aa,mob.by,mob.Z);}
    mob.Y=0;mob.ad=0;mob.bv=0;for(int i=1;i<=21;i++){mob.U();if(i>=20)System.out.printf("death %d removed=%s%n",i,mob.be);}
    world=world();mob=new Mob(world);mob.Y=20;mob.e(0,1,0);mob.bs=new Random(1234);for(int i=0;i<3;i++){mob.a((sn)null,new int[]{3,2,5}[i]);System.out.printf("damage %d health=%d hurt=%d resistance=%d previous=%d%n",i,mob.Y,mob.aa,mob.by,mob.Z);}
  }
  static void ridingVectors() throws Exception {
    World world=world();Player player=new Player(world);yl cart=new yl(world,.5,1,.5,0);player.i(cart);cart.l_();System.out.printf("ridePlayerCart feet=%.17g%n",player.aN-player.bf);player.i((sn)null);System.out.printf("dismountPlayerCart feet=%.17g%n",player.aN-player.bf);
    fz boat=new fz(world,.5,1,.5);player.i(boat);boat.l_();System.out.printf("ridePlayerBoat %.17g %.17g %.17g%n",player.aM,player.aN-player.bf,player.aO);
  }
  static void railVectors() throws Exception {
    for(int metadata=0;metadata<10;metadata++) {
      World world=world();world.rails.put(world.key(0,0,0),metadata);yl cart=new yl(world);
      bt before=cart.a(.4,.5,.4,-.3),after=cart.a(.4,.5,.4,.3);
      System.out.printf("railOffset %d %.17g %.17g %.17g %.17g %.17g %.17g%n",metadata,before.a,before.b,before.c,after.a,after.b,after.c);
    }
    World world=world();world.rails.put(world.key(0,0,0),2);world.rails.put(world.key(1,1,0),1);yl cart=new yl(world);bt point=cart.a(.9,1.4,.5,.3);System.out.printf("railOffsetEnd %.17g %.17g %.17g%n",point.a,point.b,point.c);
  }
  static void appendedTickVectors() throws Exception {
    World world=world();uw slime=new uw(world);slime.e(4);slime.e(2,1,2);slime.Y=0;slime.ad=20;slime.bs=new Random(1234);world.bodies.add(slime);
    for(int i=0;i<world.bodies.size();i++) {
      sn entity=world.bodies.get(i);entity.w_();if(entity.be)world.bodies.remove(i--);
    }
    for(sn entity:world.bodies) System.out.printf("splitTick %.17g %.17g %.17g %.17g %.17g %.17g age=%d%n",entity.aM,entity.aN,entity.aO,entity.aP,entity.aQ,entity.aR,entity.bt);
  }
  public static void main(String[] args) throws Exception { int init=uu.m.length;collisionVectors();boatVectors();livingVectors();ridingVectors();railVectors();appendedTickVectors(); }
}
