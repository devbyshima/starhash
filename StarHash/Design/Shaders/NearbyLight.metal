#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// The light where two phones meet, on People Nearby's hero sheets
// (`PhonesNodHero` in HeroSheet.swift): a field of silky light leaking from
// the gap between them, a ring that runs out at the touch, and a band of
// light that sweeps each screen from the edge nearest the other phone.
// Positions are in points. No hue: the light is the text colour's, white on
// #101010 and a soft shade on white.

static float nearbyHash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float nearbyNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    // Quintic fade: no creases where the cells meet.
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a = nearbyHash(i);
    float b = nearbyHash(i + float2(1.0, 0.0));
    float c = nearbyHash(i + float2(0.0, 1.0));
    float d = nearbyHash(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float nearbyFBM(float2 p) {
    float sum = 0.0;
    float amplitude = 0.5;
    const float2x2 turn = float2x2(0.8, -0.6, 0.6, 0.8);
    for (int octave = 0; octave < 5; octave++) {
        sum += amplitude * nearbyNoise(p);
        p = turn * p * 2.03 + float2(17.1, 9.2);
        amplitude *= 0.5;
    }
    return sum;
}

// The field behind the phones. `meet` is the gap between them, `light` how
// lit they are (0 apart, 1 together), `ripple` the ring's run from the
// touch (0 to 1; none at either end), `flash` the burst at the touch,
// `strength` how strong the light may get on this page, `tint` its colour.
[[ stitchable ]] half4 NearbyField(
    float2 position,
    half4 color,
    float2 size,
    float2 meet,
    float time,
    float light,
    float ripple,
    float flash,
    float strength,
    half4 tint
) {
    float2 d = position - meet;

    // The bloom: wide across and short up and down, as light from a gap.
    float2 q = d / float2(120.0, 60.0);
    float bloom = exp(-dot(q, q) * 1.5);

    // Silk: noise folded through itself, drifting slowly outward, so the
    // light moves like a sheet of fabric in air.
    float2 p = d / 44.0;
    float2 warp = float2(
        nearbyFBM(p + float2(0.0, time * 0.16)),
        nearbyFBM(p + float2(5.2, 1.3) - float2(time * 0.12, 0.0))
    );
    float silk = nearbyFBM(p * 1.25 + warp * 1.9 + float2(time * 0.05, -time * 0.03));
    silk = smoothstep(0.32, 0.92, silk);

    // The seam: a thin bright line level with the gap, breathing with the
    // silk, fading along its length.
    float seamWidth = 2.5 + 5.5 * warp.x;
    float seam = exp(-(d.y * d.y) / (seamWidth * seamWidth)) * exp(-(d.x * d.x) / (78.0 * 78.0));

    // Rays: faint streaks fanning out from the middle of the gap.
    float angle = atan2(d.y, d.x);
    float rayNoise = nearbyFBM(float2(angle * 2.6, time * 0.25));
    float rays = pow(0.5 + 0.5 * sin(angle * 13.0 + rayNoise * 7.0), 8.0);
    rays *= exp(-length(d) / 85.0);

    float field = bloom * (0.38 + 0.62 * silk) + seam * 0.85 + rays * bloom * 0.45;
    field *= smoothstep(0.0, 1.0, light);

    // The ring at the touch, flattened as the bloom is, thinning and fading
    // as it runs out.
    if (ripple > 0.0 && ripple < 1.0) {
        float radius = ripple * 240.0;
        float width = mix(8.0, 30.0, ripple);
        float reach = length(d * float2(1.0, 1.5));
        float ring = exp(-pow((reach - radius) / width, 2.0));
        // A softer echo just inside it.
        float echo = exp(-pow((reach - radius * 0.72) / (width * 1.6), 2.0)) * 0.35;
        float fade = smoothstep(0.0, 0.05, ripple) * pow(1.0 - ripple, 1.7);
        field += (ring + echo) * fade * 0.9;
    }

    // The burst at the touch.
    field += flash * exp(-dot(q, q) * 0.9) * 0.6;

    // Gone before every edge, so the light never meets one: no cut-off
    // anywhere, whatever the sheet's width.
    float edgeX = smoothstep(0.0, size.x * 0.2, position.x) * smoothstep(0.0, size.x * 0.2, size.x - position.x);
    float edgeY = smoothstep(0.0, size.y * 0.22, position.y) * smoothstep(0.0, size.y * 0.3, size.y - position.y);
    field *= edgeX * edgeY;

    // A little grain, so the falloff never bands.
    float grain = (nearbyHash(position + fract(time) * 61.7) - 0.5) * (2.0 / 255.0);
    float alpha = clamp(field * strength + grain * step(0.002, field), 0.0, 1.0);
    return half4(tint.rgb * half(alpha), half(alpha));
}

// A band of light sweeping a phone's screen from its top edge (the edge
// nearest the other phone) down, with a soft wake and a shimmer along it,
// as `wave` runs from 0 to 1. `color` is the screen as drawn.
[[ stitchable ]] half4 NearbyScreenWave(
    float2 position,
    half4 color,
    float2 size,
    float wave
) {
    if (color.a <= 0.0h || wave <= 0.0 || wave >= 1.0) return color;
    float y = position.y / size.y;
    float front = wave * 1.35 - 0.15;
    float band = exp(-pow((y - front) / 0.075, 2.0));
    float wake = y < front ? smoothstep(front - 0.45, front, y) * 0.3 : 0.0;
    float shimmer = 0.78 + 0.22 * sin(position.x * 0.42 + wave * 18.0 + y * 9.0);
    float strength = sin(M_PI_F * wave);
    float lift = clamp((band * shimmer + wake) * strength * 0.7, 0.0, 1.0);
    // Toward white, kept premultiplied.
    half3 lit = mix(color.rgb, half3(color.a), half(lift));
    return half4(lit, color.a);
}
