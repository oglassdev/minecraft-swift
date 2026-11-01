#!/usr/bin/env python3
"""Replay original RenderGlobal cloud methods against a recording GL/tessellator shim.

The original source stays in the ignored local reference directory. This generates
and compiles a temporary Java harness, then writes JSON vertices to stdout.
"""
import pathlib
import subprocess
import sys

source = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.build/reference/named/RenderGlobal.java').read_text()

def method(signature):
    start = source.index(signature)
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

harness = r'''
public final class CloudGeometryReference {
    final Game t = new Game(); final Texture l = new Texture(); final World k = new World(); int x;
    public static void main(String[] args) {
        double[][] positions={{0.25,64,0.75},{-0.25,108,-0.75},{123.5,112,456.75},{12550821.25,120,-12550821.75}};
        System.out.println("["); boolean first=true;
        for(boolean fancy:new boolean[]{false,true}) for(double[] position:positions) {
            CloudGeometryReference renderer=new CloudGeometryReference(); renderer.x=100;
            Entity e=renderer.t.i; e.aJ=e.aM=position[0]; e.bm=e.aN=position[1]; e.aL=e.aO=position[2];
            renderer.t.z.j=fancy; nw.a.vertices.clear(); GL11.writing=true;
            renderer.b(0.5f);
            if(!first)System.out.println(",");first=false;
            System.out.print("{\"fancy\":"+fancy+",\"position\":["+position[0]+","+position[1]+","+position[2]+"],\"vertices\":[");
            boolean firstVertex=true;
            for(float[] vertex:nw.a.vertices) {
                if(!firstVertex)System.out.print(",");firstVertex=false;
                System.out.print("[");for(int i=0;i<vertex.length;i++){if(i>0)System.out.print(",");System.out.print(vertex[i]);}System.out.print("]");
            }
            System.out.print("]}");
        }
        System.out.println("\n]");
    }
METHODS
}
final class Game { Entity i=new Entity(); Options z=new Options(); World f=new World(); }
final class Entity { double aJ,aM,bm,aN,aL,aO; }
final class Options { boolean g,j; }
final class Texture { int b(String path){return 0;} }
final class World { Provider t=new Provider(); bt c(float partial){return new bt();} }
final class Provider { boolean c; float d(){return 108;} }
final class bt { double a=1,b=1,c=1; }
final class in { static int b(double value){int i=(int)value;return value<i?i-1:i;} }
final class GL11 {
    static boolean writing=true;
    static void glDisable(int i){} static void glEnable(int i){} static void glBindTexture(int i,int j){}
    static void glBlendFunc(int i,int j){} static void glScalef(float x,float y,float z){}
    static void glColor4f(float r,float g,float b,float a){}
    static void glColorMask(boolean r,boolean g,boolean b,boolean a){writing=r||g||b;}
}
final class px { static int b; }
final class nw {
    static nw a=new nw(); java.util.List<float[]> vertices=new java.util.ArrayList<>();
    float r,g,b,alpha;
    void b(){} int a(){return 0;} void b(float nx,float ny,float nz){}
    void a(float r,float g,float b,float alpha){this.r=r;this.g=g;this.b=b;this.alpha=alpha;}
    void a(double x,double y,double z,double u,double v){if(GL11.writing)vertices.add(new float[]{(float)x,(float)y,(float)z,(float)u,(float)v,r,g,b,alpha});}
}
'''
work = pathlib.Path('.build/verification/rendering/cloud-original')
work.mkdir(parents=True, exist_ok=True)
java = work / 'CloudGeometryReference.java'
java.write_text(harness.replace('METHODS', method('public void b(float var1)') + '\n' + method('public void c(float var1)')))
subprocess.run(['javac', '-d', str(work), str(java)], check=True)
subprocess.run(['java', '-cp', str(work), 'CloudGeometryReference'], check=True)
