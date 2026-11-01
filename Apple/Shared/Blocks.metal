#include <metal_stdlib>
using namespace metal;

struct BlockVertex {
    float3 position;
    packed_float3 color;
    uint lightSamples;
    float2 uv;
    float opacity;
    float textureWeight;
};

struct Uniforms {
    float4x4 viewProjection;
    float3 renderOffset;
    float3 cameraPosition;
    float3 fogColor;
    float fogStart;
    float fogEnd;
    float skySubtraction;
    float fogDensity;
    float ambientFloor;
};

struct VertexOutput {
    float4 position [[position]];
    float3 color;
    float2 uv;
    float opacity;
    float textureWeight;
    float distance;
    float3 fogColor;
    float2 fogRange;
    float fogDensity;
};

vertex VertexOutput blockVertex(
    uint id [[vertex_id]],
    const device BlockVertex *vertices [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    BlockVertex block = vertices[id];
    VertexOutput output;
    float3 position = block.position + uniforms.renderOffset;
    output.position = uniforms.viewProjection * float4(position, 1);
    float brightness = 0;
    for (uint sample = 0; sample < 4; sample++) {
        uint light = (block.lightSamples >> (sample * 8)) & 255;
        int level = max(int(light >> 4) - int(uniforms.skySubtraction), int(light & 15));
        float darkness = 1 - float(level) / 15;
        brightness += (1 - darkness) / (darkness * 3 + 1) * (1 - uniforms.ambientFloor) + uniforms.ambientFloor;
    }
    output.color = float3(block.color) * (brightness / 4);
    output.uv = block.uv;
    output.opacity = block.opacity;
    output.textureWeight = block.textureWeight;
    output.distance = distance(position, uniforms.cameraPosition);
    output.fogColor = uniforms.fogColor;
    output.fogRange = float2(uniforms.fogStart, uniforms.fogEnd);
    output.fogDensity = uniforms.fogDensity;
    return output;
}

fragment float4 blockFragment(VertexOutput input [[stage_in]], texture2d<float> atlas [[texture(0)]]) {
    constexpr sampler pixelSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
    float4 texel = mix(float4(1), atlas.sample(pixelSampler, input.uv), input.textureWeight);
    float opacity = texel.a * input.opacity;
    if (opacity < 0.1) discard_fragment();
    float fog = input.fogDensity > 0 ? 1 - exp(-input.fogDensity * input.distance)
        : smoothstep(input.fogRange.x, input.fogRange.y, input.distance);
    return float4(mix(texel.rgb * input.color, input.fogColor, fog), opacity);
}

fragment float4 breakFragment(VertexOutput input [[stage_in]], texture2d<float> atlas [[texture(0)]]) {
    constexpr sampler pixelSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
    float4 texel = atlas.sample(pixelSampler, input.uv);
    if (texel.a < 0.1) discard_fragment();
    return float4(texel.rgb * 0.5, 1);
}

fragment float4 mapFragment(VertexOutput input [[stage_in]], texture2d<float> image [[texture(0)]]) {
    constexpr sampler pixelSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
    float4 texel = image.sample(pixelSampler, input.uv);
    return float4(texel.rgb * input.color, texel.a);
}

fragment float4 weatherFragment(VertexOutput input [[stage_in]], texture2d<float> image [[texture(0)]]) {
    constexpr sampler weatherSampler(coord::normalized, address::repeat, filter::nearest);
    float4 texel = image.sample(weatherSampler, input.uv);
    float opacity = texel.a * input.opacity;
    if (opacity < 0.01) discard_fragment();
    float fog = input.fogDensity > 0 ? 1 - exp(-input.fogDensity * input.distance)
        : smoothstep(input.fogRange.x, input.fogRange.y, input.distance);
    float3 color = input.textureWeight > 1.5 ? input.color * 0.85 + 0.15 : input.color;
    return float4(mix(texel.rgb * color, input.fogColor, fog), opacity);
}

struct SkyUniforms {
    float4x4 viewProjection;
    float3 right;
    float3 up;
    float3 forward;
    float3 sunDirection;
    float3 skyColor;
    float3 fogColor;
    float3 cloudColor;
    float3 cameraPosition;
    float4 parameters;
};

struct SkyOutput {
    float4 position [[position]];
    float2 screen;
};

vertex SkyOutput skyVertex(uint id [[vertex_id]]) {
    float2 point = float2(id == 1 ? 3 : -1, id == 2 ? 3 : -1);
    return { float4(point, 1, 1), point };
}

float3 skyRay(float2 screen, constant SkyUniforms &uniforms) {
    return normalize(uniforms.forward + uniforms.right * screen.x * uniforms.parameters.x * uniforms.parameters.y
        + uniforms.up * screen.y * uniforms.parameters.y);
}

float3 celestialTexel(float3 ray, float3 direction, texture2d<float> image, float scale) {
    float facing = dot(ray, direction);
    if (facing <= 0) return float3(0);
    float3 right = float3(0, 0, 1);
    float3 up = cross(direction, right);
    float2 uv = float2(dot(ray, right), -dot(ray, up)) / facing / scale + 0.5;
    if (any(uv < 0) || any(uv > 1)) return float3(0);
    constexpr sampler pixelSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
    float4 color = image.sample(pixelSampler, uv);
    return color.rgb * color.a;
}

fragment float4 skyFragment(SkyOutput input [[stage_in]], constant SkyUniforms &uniforms [[buffer(0)]],
    texture2d<float> sun [[texture(0)]], texture2d<float> moon [[texture(1)]]) {
    if (uniforms.parameters.w < 0) return float4(uniforms.fogColor, 1);
    float3 ray = skyRay(input.screen, uniforms);
    float horizon = pow(saturate(ray.y), 0.35);
    float3 color = mix(uniforms.fogColor, uniforms.skyColor, horizon);
    if (ray.y < -0.05) color *= saturate(1 + ray.y * 3);
    color += celestialTexel(ray, uniforms.sunDirection, sun, 0.6);
    color += celestialTexel(ray, -uniforms.sunDirection, moon, 0.4);
    return float4(color, 1);
}

fragment float4 cloudFragment(SkyOutput input [[stage_in]], constant SkyUniforms &uniforms [[buffer(0)]],
    texture2d<float> clouds [[texture(2)]]) {
    if (uniforms.parameters.w < 0) discard_fragment();
    float3 ray = skyRay(input.screen, uniforms);
    if (abs(ray.y) < 0.001) discard_fragment();
    float distance = (128 - uniforms.cameraPosition.y) / ray.y;
    if (distance <= 0 || distance > 1024) discard_fragment();
    float3 point = uniforms.cameraPosition + ray * distance;
    constexpr sampler cloudSampler(coord::normalized, address::repeat, filter::nearest);
    float4 color = clouds.sample(cloudSampler, (point.xz + float2(uniforms.parameters.z, 0)) / 2048);
    color.rgb *= uniforms.cloudColor;
    color.a *= 0.8 * (1 - smoothstep(256.0, 1024.0, distance));
    if (color.a < 0.01) discard_fragment();
    return color;
}

struct StarOutput {
    float4 position [[position]];
    float brightness;
};

vertex StarOutput starVertex(uint id [[vertex_id]], const device float4 *vertices [[buffer(0)]],
    constant SkyUniforms &uniforms [[buffer(1)]]) {
    return { uniforms.viewProjection * vertices[id], uniforms.parameters.w };
}

fragment float4 starFragment(StarOutput input [[stage_in]]) {
    return float4(float3(1), input.brightness);
}
