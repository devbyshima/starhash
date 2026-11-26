#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Hold Near's Paid moment (`PaidMoment` in HoldNearSheet.swift): the money
// lands where the owner's photo was, as a drop lands in water. A ring bends
// the sheet outward from it (PaidRipple), green light opens behind it with
// glints as the tick lands and settles into a faint halo (PaidBloom), and a
// sheen crosses the green disc (PaidDiscSheen). Times are in seconds since
// the payment landed; positions in points.

// MARK: Noise

static float paidHash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float paidNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = paidHash(i);
    float b = paidHash(i + float2(1.0, 0.0));
    float c = paidHash(i + float2(0.0, 1.0));
    float d = paidHash(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float paidFbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int octave = 0; octave < 3; octave++) {
        value += amplitude * paidNoise(p);
        p = p * 2.07 + 11.3;
        amplitude *= 0.55;
    }
    return value / 0.8;
}

// MARK: Ripple

// The sheet bent by one ring going out from `origin`: a damped wave packet
// `width` wide, travelling `speed` points a second, pushing what it passes
// `amplitude` points outward at most and lifting its crest a touch. Fades
// out as it travels, so it ends by itself.
[[ stitchable ]] half4 PaidRipple(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float elapsed,
    float amplitude,
    float speed,
    float width
) {
    float2 delta = position - origin;
    float distanceFromOrigin = length(delta);
    float x = distanceFromOrigin - elapsed * speed;
    float envelope = exp(-(x * x) / (width * width)) * exp(-elapsed * 2.4);
    float wave = sin(x / width * M_PI_F) * envelope;
    float2 direction = distanceFromOrigin > 0.001 ? delta / distanceFromOrigin : float2(0.0);
    half4 color = layer.sample(position - direction * wave * amplitude);
    color.rgb += half3(max(wave, 0.0) * 0.08) * color.a;
    return color;
}

// MARK: Bloom

// One four-pointed glint: a thin cross with a soft core, `size` points
// across, at `scale` of its full size.
static float paidGlint(float2 p, float size, float scale) {
    if (scale <= 0.0) { return 0.0; }
    float2 q = abs(p) / (size * scale);
    float cross = exp(-q.x * 9.0) * exp(-q.y * 1.6) + exp(-q.y * 9.0) * exp(-q.x * 1.6);
    float core = exp(-dot(q, q) * 6.0);
    return (cross * 0.8 + core) * scale;
}

// Green light behind the disc: opens from `origin` with the ripple's ring,
// swirls a little, and settles to `rest` of its peak, a halo that stays.
// Seven glints twinkle round the disc as the tick lands. `tap` is the time
// since the owner last tapped the disc (negative for never), which sends a
// smaller ring out again. `tint` is the light's colour.
[[ stitchable ]] half4 PaidBloom(
    float2 position,
    half4 color,
    float2 origin,
    float elapsed,
    float tap,
    float discRadius,
    float rest,
    half4 tint
) {
    if (elapsed < 0.0) { return half4(0.0); }
    float2 delta = position - origin;
    float r = length(delta);
    float angle = atan2(delta.y, delta.x);

    // The light: rises over a third of a second, then eases to its rest.
    float rise = smoothstep(0.0, 0.35, elapsed);
    float fall = exp(-max(elapsed - 0.35, 0.0) * 2.2);
    float level = rise * mix(rest, 1.0, fall);
    float radius = discRadius * mix(1.1, 2.5, 1.0 - exp(-elapsed * 3.0));
    float swirl = paidFbm(float2(angle * 1.4 + elapsed * 0.35, r / discRadius * 0.9 - elapsed * 0.8));
    float glow = exp(-pow(r / radius, 2.0) * 1.8) * (0.45 + 0.4 * swirl) * level;

    // The ring going out with the ripple, and a smaller one for a tap.
    float front = discRadius + elapsed * 560.0;
    float ring = exp(-pow((r - front) / 7.0, 2.0)) * exp(-elapsed * 4.5) * 0.4;
    if (tap >= 0.0) {
        float tapFront = discRadius + tap * 240.0;
        ring += exp(-pow((r - tapFront) / 6.0, 2.0)) * exp(-tap * 5.0) * 0.35;
    }

    // Glints as the tick lands: each at its own angle and distance,
    // twinkling once, drifting outward a little.
    float glints = 0.0;
    for (int i = 0; i < 7; i++) {
        float seed = float(i) + 1.0;
        float glintAngle = (float(i) / 7.0) * 2.0 * M_PI_F + paidHash(float2(seed, 3.1)) * 0.7;
        float start = 0.36 + paidHash(float2(seed, 7.7)) * 0.12;
        float life = clamp((elapsed - start) / 0.42, 0.0, 1.0);
        float twinkle = sin(life * M_PI_F);
        float distanceOut = discRadius * (1.35 + paidHash(float2(seed, 1.9)) * 0.55 + life * 0.25);
        float2 at = origin + float2(cos(glintAngle), sin(glintAngle)) * distanceOut;
        float size = 5.0 + paidHash(float2(seed, 5.3)) * 6.0;
        glints += paidGlint(position - at, size, twinkle);
    }

    float intensity = clamp(glow + ring + glints * 0.9, 0.0, 1.0);
    half alpha = half(intensity) * tint.a;
    return half4(tint.rgb * alpha, alpha);
}

// MARK: Disc sheen

// One band of light crossing the disc corner to corner as `progress` goes
// from 0 to 1, over what is drawn (the disc's own pixels only).
[[ stitchable ]] half4 PaidDiscSheen(
    float2 position,
    half4 color,
    float2 size,
    float progress
) {
    if (progress <= 0.0 || progress >= 1.0) { return color; }
    float2 uv = position / size;
    float diagonal = (uv.x + uv.y) * 0.5;
    float centre = mix(-0.3, 1.3, progress);
    float band = exp(-pow((diagonal - centre) / 0.11, 2.0)) * 0.55;
    color.rgb += half3(band) * color.a;
    return color;
}
