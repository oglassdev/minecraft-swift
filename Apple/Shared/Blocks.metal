#include <metal_stdlib>
using namespace metal;

struct BlockVertex {
    float3 position;
    float3 color;
};

struct Uniforms {
    float4x4 viewProjection;
    float3 cameraPosition;
};

struct VertexOutput {
    float4 position [[position]];
    float3 color;
    float distance;
};

vertex VertexOutput blockVertex(
    uint id [[vertex_id]],
    const device BlockVertex *vertices [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    BlockVertex block = vertices[id];
    VertexOutput output;
    output.position = uniforms.viewProjection * float4(block.position, 1);
    output.color = block.color;
    output.distance = distance(block.position, uniforms.cameraPosition);
    return output;
}

fragment float4 blockFragment(VertexOutput input [[stage_in]]) {
    float fog = smoothstep(25.0, 65.0, input.distance);
    return float4(mix(input.color, float3(0.57, 0.75, 0.90), fog), 1);
}
