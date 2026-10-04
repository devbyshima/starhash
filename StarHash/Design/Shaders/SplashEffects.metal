#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// The launch splash's shimmer, after Beam's: a soft band of light that
// crosses the raised StarHash mark on the diagonal, once every two
// seconds, only where the mark is drawn. It fades in and out on a curve
// rather than at a hard edge, so it reads as light passing over the
// mark's relief, not a stripe laid across a flat shape.

[[ stitchable ]] half4 splashShimmer(float2 position, SwiftUI::Layer layer, float2 size, float time) {
    half4 source = layer.sample(position);
    float2 uv = position / max(size, float2(1.0));
    // 0 to 1 along the diagonal, top left to bottom right.
    float band = (uv.x + uv.y) * 0.5;
    // Fully across and off again, with a margin either side.
    float centre = fract(time * 0.5) * 1.6 - 0.3;
    float distance = (band - centre) / 0.22;
    float strength = exp(-distance * distance) * 0.38;
    source.rgb += half3(half(strength)) * source.a;
    return source;
}
