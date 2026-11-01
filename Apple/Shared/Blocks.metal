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
    constexpr sampler pixelSampler(coord::normalized, address::repeat, filter::nearest);
    float4 texel = mix(float4(1), atlas.sample(pixelSampler, input.uv), input.textureWeight);
    float opacity = texel.a * input.opacity;
    if (opacity < 0.1) discard_fragment();
    float fog = input.fogDensity > 0 ? 1 - exp(-input.fogDensity * input.distance)
        : saturate((input.distance - input.fogRange.x) / (input.fogRange.y - input.fogRange.x));
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

fragment float4 overlayFragment(VertexOutput input [[stage_in]], texture2d<float> image [[texture(0)]]) {
    constexpr sampler pixelSampler(coord::normalized, address::repeat, filter::nearest);
    float4 texel = image.sample(pixelSampler, input.uv);
    return float4(texel.rgb * input.color, texel.a * input.opacity);
}

fragment float4 overlayBlurFragment(VertexOutput input [[stage_in]], texture2d<float> image [[texture(0)]]) {
    constexpr sampler imageSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    float4 texel = image.sample(imageSampler, input.uv);
    return float4(texel.rgb * input.color, texel.a * input.opacity);
}

fragment float4 weatherFragment(VertexOutput input [[stage_in]], texture2d<float> image [[texture(0)]]) {
    constexpr sampler weatherSampler(coord::normalized, address::repeat, filter::nearest);
    float4 texel = image.sample(weatherSampler, input.uv);
    float opacity = texel.a * input.opacity;
    if (opacity < 0.01) discard_fragment();
    float fog = input.fogDensity > 0 ? 1 - exp(-input.fogDensity * input.distance)
        : saturate((input.distance - input.fogRange.x) / (input.fogRange.y - input.fogRange.x));
    float3 color = input.textureWeight > 1.5 ? input.color * 0.85 + 0.15 : input.color;
    return float4(mix(texel.rgb * color, input.fogColor, fog), opacity);
}

struct SkyAppearance {
    float4 tint;
    float2 uvOffset;
    float3 fogScale;
};

vertex VertexOutput skyGeometryVertex(uint id [[vertex_id]],
    const device BlockVertex *vertices [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]], constant SkyAppearance &appearance [[buffer(2)]]) {
    BlockVertex block = vertices[id];
    VertexOutput output;
    float3 position = block.position + uniforms.renderOffset;
    output.position = uniforms.viewProjection * float4(position,1);
    output.color = float3(block.color) * appearance.tint.rgb;
    output.uv = block.uv + appearance.uvOffset;
    output.opacity = block.opacity * appearance.tint.a;
    output.textureWeight = block.textureWeight;
    output.distance = length(position * appearance.fogScale);
    output.fogColor = uniforms.fogColor;
    output.fogRange = float2(uniforms.fogStart,uniforms.fogEnd);
    output.fogDensity = uniforms.fogDensity;
    return output;
}

fragment float4 skyGeometryFragment(VertexOutput input [[stage_in]],texture2d<float> image [[texture(0)]]) {
    constexpr sampler pixelSampler(coord::normalized,address::repeat,filter::nearest);
    float4 texel = mix(float4(1),image.sample(pixelSampler,input.uv),input.textureWeight);
    float fog = input.fogDensity > 0 ? 1-exp(-input.fogDensity*input.distance)
        : saturate((input.distance-input.fogRange.x)/(input.fogRange.y-input.fogRange.x));
    return float4(mix(texel.rgb*input.color,input.fogColor,fog),texel.a*input.opacity);
}

fragment float4 cloudGeometryFragment(VertexOutput input [[stage_in]],texture2d<float> image [[texture(0)]]) {
    constexpr sampler pixelSampler(coord::normalized,address::repeat,filter::nearest);
    float4 texel = image.sample(pixelSampler,input.uv);
    float opacity = texel.a*input.opacity;
    if (opacity <= 0.1) discard_fragment();
    float fog = input.fogDensity > 0 ? 1-exp(-input.fogDensity*input.distance)
        : saturate((input.distance-input.fogRange.x)/(input.fogRange.y-input.fogRange.x));
    return float4(mix(texel.rgb*input.color,input.fogColor,fog),opacity);
}
