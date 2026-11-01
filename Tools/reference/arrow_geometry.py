#!/usr/bin/env python3
"""Record the original arrow renderer's vertices with an isolated GL shim.

Requires the ignored client reference prepared by prepare_reference.py and a JDK.
Generated Java and JSON remain under .build; no client code is checked in.
"""

import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[2]
source = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else root / ".build/reference/named/RenderArrow.java"
output = root / ".build/verification/arrow-oracle"
output.mkdir(parents=True, exist_ok=True)
renderer = source.read_text().replace("import org.lwjgl.opengl.GL11;", "").replace("public class mc", "class mc")
shim = r'''
import java.util.*;
class bw { void a(String name) {} }
class sl { float aU, aS, aV, aT; int b; }
class in {
    static float a(float value) {
        int index = (int)(value * 10430.378F) & 65535;
        return (float)Math.sin(index * Math.PI * 2 / 65536);
    }
}
class GL11 {
    static double[] matrix = identity();
    static final Deque<double[]> stack = new ArrayDeque<>();
    static double[] identity() {
        double[] result = new double[16];
        for (int i = 0; i < 4; i++) result[i * 5] = 1;
        return result;
    }
    static void multiply(double[] right) {
        double[] result = new double[16];
        for (int column = 0; column < 4; column++) for (int row = 0; row < 4; row++)
            for (int k = 0; k < 4; k++) result[column * 4 + row] += matrix[k * 4 + row] * right[column * 4 + k];
        matrix = result;
    }
    static void glPushMatrix() { stack.push(matrix.clone()); }
    static void glPopMatrix() { matrix = stack.pop(); }
    static void glTranslatef(float x, float y, float z) {
        double[] m = identity(); m[12] = x; m[13] = y; m[14] = z; multiply(m);
    }
    static void glScalef(float x, float y, float z) {
        double[] m = identity(); m[0] = x; m[5] = y; m[10] = z; multiply(m);
    }
    static void glRotatef(float degrees, float x, float y, float z) {
        double angle = degrees * Math.PI / 180, c = Math.cos(angle), s = Math.sin(angle), t = 1 - c;
        double[] m = identity();
        m[0]=t*x*x+c; m[4]=t*x*y-s*z; m[8]=t*x*z+s*y;
        m[1]=t*x*y+s*z; m[5]=t*y*y+c; m[9]=t*y*z-s*x;
        m[2]=t*x*z-s*y; m[6]=t*y*z+s*x; m[10]=t*z*z+c; multiply(m);
    }
    static void glEnable(int capability) {}
    static void glDisable(int capability) {}
    static void glNormal3f(float x, float y, float z) {}
}
class nw {
    static final nw a = new nw();
    static final List<double[]> vertices = new ArrayList<>();
    void b() {}
    void a() {}
    void a(double x, double y, double z, double u, double v) {
        double[] m = GL11.matrix;
        vertices.add(new double[]{m[0]*x+m[4]*y+m[8]*z+m[12], m[1]*x+m[5]*y+m[9]*z+m[13],
            m[2]*x+m[6]*y+m[10]*z+m[14],u,v});
    }
}
public class ArrowReference {
    public static void main(String[] args) {
        boolean first = true;
        System.out.print("[");
        for (int yaw : new int[]{-135,-45,0,45,90,135}) for (int pitch : new int[]{-60,0,30})
            for (int shake : new int[]{0,7}) {
                sl entity = new sl(); entity.aU=entity.aS=180-yaw; entity.aV=entity.aT=pitch; entity.b=shake;
                nw.vertices.clear(); GL11.matrix=GL11.identity();
                new mc().a(entity,0,0,0,0,0.25F);
                if (!first) System.out.print(","); first=false;
                System.out.print("{\"yaw\":"+yaw+",\"pitch\":"+pitch+",\"shake\":"+shake+",\"vertices\":[");
                for (int i=0;i<nw.vertices.size();i++) {
                    if (i>0) System.out.print(","); System.out.print(Arrays.toString(nw.vertices.get(i)));
                }
                System.out.print("]}");
            }
        System.out.println("]");
    }
}
'''
java = output / "ArrowReference.java"
java.write_text(shim + renderer)
subprocess.run(["javac", "-d", str(output), str(java)], check=True)
result = subprocess.run(["java", "-cp", str(output), "ArrowReference"], check=True, capture_output=True)
fixture = output / "vertices.json"
fixture.write_bytes(result.stdout)
print(f"Recorded 36 original arrow poses in {fixture.relative_to(root)}")
