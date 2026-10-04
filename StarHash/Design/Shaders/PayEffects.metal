#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Pay's effect, after the reference "SIP, send money": the sheen in Pay
// while it is held. (The wave it once sent up the screen is the Send
// Ripple, in SendRipple.metal.)

// MARK: Noise

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm3(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int octave = 0; octave < 3; octave++) {
        value += amplitude * valueNoise(p);
        p = p * 2.03 + 17.1;
        amplitude *= 0.57;
    }
    return value / 0.8;
}

// MARK: Pay sheen

// Pay while held: lighter, liquid streaks drifting through the button's
// colour. White, to lie over the button; `size` is the button's.
[[ stitchable ]] half4 PayButtonSheen(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float strength
) {
    float2 uv = position / size.y;
    float flow = fbm3(float2(uv.x * 1.4 - time * 0.9, uv.y * 2.2 + time * 0.35));
    float streak = smoothstep(0.52, 0.78, flow);
    // Only where the button is.
    half alpha = half(clamp(streak * 0.7, 0.0, 1.0) * strength) * color.a;
    return half4(half3(alpha), alpha);
}
