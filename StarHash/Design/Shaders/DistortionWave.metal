#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// The Distortion Wave, after the owner's reference (a distortion waves
// effect library), on the confirmation sheets: drawn over snapshots of the
// sheet before and after and those snapshots out of focus (`DistortionWave`
// in DistortionWave.swift). Positions are in points.

constexpr sampler waveSampler(coord::normalized, address::clamp_to_edge, filter::linear);

static half4 tap(texture2d<half> image, float2 position, float2 size) {
    return image.sample(waveSampler, position / size);
}

// The out-of-focus snapshots share one image, side by side (SwiftUI takes
// three images at most): `which` 0 for the state before, 1 after.
static half4 tapSoft(texture2d<half> pair, float2 position, float2 size, float which) {
    float2 uv = clamp(position / size, float2(0.002), float2(0.998));
    return pair.sample(waveSampler, float2((uv.x + which) * 0.5, uv.y));
}

// How far inside a rounded rectangle of `size` a point is (negative
// inside), for the glow round its edges.
static float roundedDistance(float2 position, float2 size, float corner) {
    float2 q = abs(position - size * 0.5) - (size * 0.5 - corner);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
}

// The sheet's wave: a ring of `tint` opening from the icon at `origin`,
// out of focus where it passes, the new state behind it, lighting the
// sheet's edges (a rounded rectangle, `corner` its radius) as it reaches
// them and after it has gone. Outside the sheet it draws nothing, so what
// is behind shows.
[[ stitchable ]] half4 SheetWave(
    float2 position,
    half4 color,
    float2 size,
    float2 origin,
    float radius,
    float time,
    float pre,
    float reveal,
    float haze,
    float edge,
    float dark,
    float corner,
    half4 tint,
    texture2d<half> before,
    texture2d<half> after,
    texture2d<half> soft
) {
    float shape = roundedDistance(position, size, corner);
    float within = 1.0 - smoothstep(-1.0, 0.5, shape);
    if (within <= 0.0) return half4(0.0h);

    float2 delta = position - origin;
    float reach = length(delta);
    float2 direction = reach > 0.001 ? delta / reach : float2(0.0, -1.0);
    float alive = smoothstep(0.0, 24.0, radius);
    // Its edge swells and settles as a liquid's does.
    float turn = atan2(delta.x, -delta.y);
    float d = reach - radius - alive * (sin(turn * 6.0 + time * 5.0) * 3.0 + sin(turn * 11.0 - time * 4.0) * 1.5);

    // The ring: a thick soft band, its leading edge lighter, its trail a
    // haze of the colour fading behind it.
    float ring = exp(-pow((d + 26.0) / 34.0, 2.0)) * alive;
    float lead = exp(-pow((d + 4.0) / 10.0, 2.0)) * alive;
    float trail = exp(min(d + 40.0, 0.0) / 110.0) * (1.0 - smoothstep(-40.0, 0.0, d)) * alive * haze;
    float ahead = exp(-pow(max(d, 0.0) / 40.0, 2.0)) * step(0.0, d) * alive;
    // Before it opens, the icon's surroundings ripple, as a drop landing.
    float swell = pre * exp(-pow(reach / 90.0, 2.0));

    // The new state behind the front.
    float behind = 1.0 - smoothstep(-30.0, 6.0, d);
    behind = max(behind, step(0.999, reveal));
    float2 smeared = position - direction * (ring * 10.0 + swell * 3.0 * sin(reach * 0.08 - time * 14.0));
    half4 sharp = mix(tap(before, smeared, size), tap(after, smeared, size), half(behind));
    half4 frost = mix(tapSoft(soft, smeared, size, 0.0), tapSoft(soft, smeared, size, 1.0), half(behind));
    float focus = clamp(ring * 1.1 + ahead * 0.3 + swell * 0.3, 0.0, 1.0) * clamp(haze * 4.0, 0.0, 1.0);
    float3 rgb = float3(mix(sharp.rgb, frost.rgb, half(focus)));

    float3 glow = float3(tint.rgb);
    float fromEdge = max(-shape, 0.0);
    // The edges light where the ring meets them, and all round as it goes.
    float edgeLine = exp(-fromEdge / 12.0) * clamp(edge + ring * 1.4 + trail * 0.6, 0.0, 1.2);
    float edgeHaze = exp(-fromEdge / 46.0) * clamp(edge * 0.6 + ring * 0.8, 0.0, 1.0);

    if (dark > 0.5) {
        rgb = mix(rgb, rgb * 0.55 + glow * 0.32, ring * 0.7);
        rgb += glow * (ring * 0.75 + trail * 0.28 + edgeLine * 1.0 + edgeHaze * 0.35);
        rgb += mix(glow, float3(1.0), 0.6) * lead * 0.5;
        return half4(half3(min(rgb, 1.0)), 1.0h) * half(within);
    }
    rgb = mix(rgb, glow, clamp(ring * 0.62 + trail * 0.18, 0.0, 1.0));
    rgb = mix(rgb, mix(glow, float3(1.0), 0.55), lead * 0.45);
    rgb = mix(rgb, glow, clamp(edgeLine * 0.85 + edgeHaze * 0.2, 0.0, 1.0));
    return half4(half3(clamp(rgb, 0.0, 1.0)), 1.0h) * half(within);
}

