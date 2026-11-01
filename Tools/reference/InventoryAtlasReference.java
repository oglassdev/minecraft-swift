import java.lang.reflect.*;
import java.io.*;
public final class InventoryAtlasReference {
 public static void main(String[] args)throws Exception {
  PrintStream out=System.out;System.setOut(new PrintStream(new ByteArrayOutputStream()));
  Class<?> c=Class.forName("uu");Field f=c.getDeclaredField("m");f.setAccessible(true);Object[] blocks=(Object[])f.get(null);
  Method m=c.getDeclaredMethod("a",int.class,int.class);m.setAccessible(true);System.setOut(out);
  for(int id=1;id<=96;id++)for(int side=0;side<6;side++)for(int data=0;data<16;data++){
   try {out.printf("%d,%d,%d,%d%n",id,side,data,m.invoke(blocks[id],side,data));}
   catch(InvocationTargetException e){out.printf("%d,%d,%d,error%n",id,side,data);}
  }
 }
}
