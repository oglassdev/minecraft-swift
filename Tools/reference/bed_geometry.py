#!/usr/bin/env python3
"""Record original bed vertices/UVs; source and generated Java stay under .build."""
import json
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[2]
reference = root / ".build/reference/named"
source = (reference / "RenderBlocks.java").read_text()


def method(text, signature):
    start = text.index(signature)
    opening = text.index("{", start)
    depth, end = 1, opening + 1
    while depth:
        depth += (text[end] == "{") - (text[end] == "}")
        end += 1
    return text[start:end]


methods = [method(source, "private boolean q(uu var1, int var2, int var3, int var4)")]
methods += [method(source, f"public void {face}(uu var1, double var2, double var4, double var6, int var8)")
            for face in "cdef"]
fields = source[source.index("   private xp c;"):source.index("   public cv(xp var1)")]
texture = method((reference / "BlockBed.java").read_text(), "public int a(int var1, int var2)")
harness = r'''
import java.util.*;
public class BedGeometryReference {
FIELDS
METHODS
    public static void main(String[] args) {
        System.out.print("["); boolean first=true;
        for (int metadata=0;metadata<16;metadata++) for(int blocked=-1;blocked<6;blocked++) {
            BedGeometryReference renderer=new BedGeometryReference(); renderer.c=new xp(metadata,blocked);
            nw.a.vertices.clear(); renderer.q(new uu(),0,0,0);
            if(!first)System.out.print(",");first=false;
            System.out.print("{\"metadata\":"+metadata+",\"blockedFace\":"+blocked+",\"vertices\":[");
            for(int i=0;i<nw.a.vertices.size();i++) {
                if(i>0)System.out.print(",");System.out.print(Arrays.toString(nw.a.vertices.get(i)));
            }
            System.out.print("]}");
        }
        System.out.println("]");
    }
}
class xp {
    int metadata,blocked;
    xp(int metadata,int blocked){this.metadata=metadata;this.blocked=blocked;}
    int e(int x,int y,int z){return metadata;}
}
class uu {
    static uu y=new uu(); int bm=134;
    double bs=0,bt=0,bu=0,bv=1,bw=0.5625,bx=1;
    float d(xp world,int x,int y,int z){return 1;}
    boolean b(xp world,int x,int y,int z,int face){return world.blocked!=face;}
    int a(xp world,int x,int y,int z,int face){return a(face,world.metadata);}
TEXTURE
}
class ve { static int d(int data){return data&3;} static boolean e(int data){return(data&8)!=0;} }
class jj {
    static int[] a={3,4,2,5},b={2,3,0,1};
    static int[][] c={{1,0,3,2,5,4},{1,0,5,4,2,3},{1,0,2,3,4,5},{1,0,4,5,3,2}};
}
class nw {
    static nw a=new nw(); float r,g,b;
    List<double[]> vertices=new ArrayList<>();
    void a(float r,float g,float b){this.r=r;this.g=g;this.b=b;}
    void a(double x,double y,double z,double u,double v){vertices.add(new double[]{x,y,z,u,v,r,g,b});}
}
'''
# BlockBed's bottom references planks; the shim's block instance is otherwise the bed.
texture = texture.replace("uu.y.bm", "4").replace("d(var2)", "ve.d(var2)").replace("e(var2)", "ve.e(var2)")
harness = harness.replace("FIELDS", fields).replace("METHODS", "\n".join(methods)).replace("TEXTURE", texture)
output = root / ".build/verification/bed-oracle"
output.mkdir(parents=True, exist_ok=True)
java = output / "BedGeometryReference.java"
java.write_text(harness)
subprocess.run(["javac", "-d", str(output), str(java)], check=True)
result = subprocess.run(["java", "-cp", str(output), "BedGeometryReference"], check=True, capture_output=True)
cases = json.loads(result.stdout)
fixture = root / "Tests/MinecraftCoreTests/Fixtures/BedGeometry.json"
fixture.write_text(json.dumps(cases, separators=(",", ":")) + "\n")
print(f"Recorded {len(cases)} original bed cases in {fixture.relative_to(root)}")
