#include <metal_stdlib>
using namespace metal;

struct QuadOut {
    float4 position [[position]];
    float2 uv;
};

// Draws one textured quad. rect is (left, bottom, right, top) in clip space.
vertex QuadOut quadVertex(uint vid [[vertex_id]], constant float4 &rect [[buffer(0)]]) {
    float2 uv = float2(vid & 1, vid >> 1);
    QuadOut out;
    out.position = float4(mix(rect.x, rect.z, uv.x), mix(rect.w, rect.y, uv.y), 0, 1);
    out.uv = uv;
    return out;
}

fragment float4 quadFragment(QuadOut in [[stage_in]],
                             texture2d<float> frame [[texture(0)]],
                             sampler linear [[sampler(0)]]) {
    return frame.sample(linear, in.uv);
}
