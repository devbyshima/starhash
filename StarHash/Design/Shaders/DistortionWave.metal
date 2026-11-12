#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// The Distortion Wave's two kinds, after the owner's reference (a
// distortion waves effect library), drawn over snapshots of the state
// before and after a change and those snapshots out of focus
// (`DistortionWave` in DistortionWave.swift). Positions are in points.

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

// The screen's wave. `radius` is the bubble's front; `pre` the shimmer
// before it forms; `reveal` how far the new screen shows inside it; `haze`
// how out of focus and tinted its inside is; `edge` the glow round the
// screen; `dark` 1 in dark mode, where light adds onto the screen, and 0 in
// light, where it tints it; `tint` its colour, the sheet wave's green.
[[ stitchable ]] half4 DistortionWave(
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
    float4 hole,
    half4 tint,
    texture2d<half> before,
    texture2d<half> after,
    texture2d<half> soft
) {
    // The bubble forms wide and low, a band across the screen, and rounds
    // out as it rises, as the reference's: flattened while small.
    float stretch = mix(1.7, 1.0, smoothstep(0.0, size.y * 0.55, radius));
    float2 delta = position - origin;
    float2 shaped = float2(delta.x / stretch, delta.y);
    float reach = length(shaped);
    float2 direction = length(delta) > 0.001 ? normalize(delta) : float2(0.0, -1.0);
    float formed = smoothstep(0.0, 60.0, radius);
    // Behind the front is negative, ahead positive. The front moves as a
    // liquid's does, its edge swelling and settling as it goes.
    float turn = atan2(shaped.x, -shaped.y);
    float d = reach - radius - formed * (sin(turn * 5.0 + time * 5.0) * 5.0 + sin(turn * 9.0 - time * 3.5) * 2.5);

    // Inside the bubble, with a soft wall.
    float inside = (1.0 - smoothstep(-40.0, 12.0, d)) * formed;

    // The tab bar's capsule (`hole`: x, y, width, height): the screen
    // before, still, until the bubble takes it, then clear, so the live bar
    // shows over the wave, as the reference's button stays over its bubble.
    float open = 1.0;
    if (hole.z > 0.0) {
        float fromBar = roundedDistance(position - hole.xy, hole.zw, hole.w * 0.5);
        float onBar = 1.0 - smoothstep(-0.5, 1.0, fromBar);
        if (onBar > 0.0) {
            float shown = 1.0 - smoothstep(0.25, 0.75, inside);
            half4 still = tap(before, position, size) * half(shown);
            if (onBar >= 1.0) return still;
            open = 1.0 - onBar;
        }
    }
    // The rim: a bright soft band just inside the front, a wash of the
    // colour behind it, and the lens's reach ahead of it.
    float band = exp(-pow((d + 16.0) / 36.0, 2.0)) * formed;
    float core = exp(-pow((d + 6.0) / 13.0, 2.0)) * formed;
    float wash = exp(-pow((d + 90.0) / 60.0, 2.0)) * formed;
    float ahead = exp(-pow(max(d, 0.0) / 120.0, 2.0)) * step(0.0, d) * formed;
    // Before it forms, what is near where it will rises in slow ripples,
    // as liquid does before it spills.
    float shimmer = pre * exp(-pow(length(delta) / 260.0, 2.0));

    // The lens: what the front is about to cross is pushed out, as through
    // a drop, and its colours part a little at the edge.
    float2 moved = position - direction * (ahead * 16.0 + band * 12.0);
    moved -= direction * shimmer * 4.0 * sin(length(delta) * 0.06 - time * 14.0);
    float split = ahead * 4.0 + band * 8.0 + shimmer * 2.0 + inside * haze * 3.0;
    float2 apart = direction * split;

    half4 sharp = mix(tap(before, moved, size), tap(after, moved, size), half(reveal));
    half4 sharpRed = mix(tap(before, moved + apart, size), tap(after, moved + apart, size), half(reveal));
    half4 sharpBlue = mix(tap(before, moved - apart, size), tap(after, moved - apart, size), half(reveal));
    half3 clear = half3(sharpRed.r, sharp.g, sharpBlue.b);

    float2 swirl = moved - direction * wash * 18.0;
    half4 frost = mix(tapSoft(soft, swirl, size, 0.0), tapSoft(soft, swirl, size, 1.0), half(reveal));
    half4 frostRed = mix(tapSoft(soft, swirl + apart * 1.6, size, 0.0), tapSoft(soft, swirl + apart * 1.6, size, 1.0), half(reveal));
    half4 frostBlue = mix(tapSoft(soft, swirl - apart * 1.6, size, 0.0), tapSoft(soft, swirl - apart * 1.6, size, 1.0), half(reveal));
    half3 frosted = half3(frostRed.r, frost.g, frostBlue.b);

    float focus = clamp(inside * haze + band * 0.8 + shimmer * 0.35, 0.0, 1.0);
    float3 rgb = float3(mix(clear, frosted, half(focus)));

    // The colour is the sheet wave's (`tint`, green), at the owner's ask:
    // the rim mint over the top, the full colour down the sides, deeper
    // below, a slow shimmer between them as it goes.
    float3 glow = float3(tint.rgb);
    float3 mint = mix(glow, float3(1.0), 0.55);
    float around = abs(atan2(shaped.x, -shaped.y));
    float3 rim = mix(mint, glow, smoothstep(0.2, 1.3, around));
    rim = mix(rim, glow * 0.8, smoothstep(1.4, 2.4, around));
    rim = mix(rim, mint, 0.2 * (0.5 + 0.5 * sin(around * 3.0 + time * 2.4)));
    // Deep green inside, in linear light as the shader works: near black
    // with the colour in it, as the reference's bubble is near black purple.
    float low = smoothstep(origin.y - 200.0, size.y, position.y);
    float3 depth = glow * mix(0.07, 0.05, low);

    // The edges, once the bubble has gone: a glow along every side,
    // shimmering between the colour and its light, and a wider haze inside.
    float fromEdge = max(-roundedDistance(position, size, 55.0), 0.0);
    float2 centred = (position - size * 0.5) / size;
    float3 edgeColour = mix(glow, mint, 0.5 + 0.5 * sin(atan2(centred.y, centred.x) * 2.0 + time * 1.6));
    float edgeLine = exp(-fromEdge / 14.0) * edge;
    float edgeHaze = exp(-fromEdge / 70.0) * edge;

    if (dark > 0.5) {
        float tinted = inside * haze;
        rgb = mix(rgb, rgb * 0.55 + depth, tinted * 0.9);
        rgb += rim * band * 0.95 + float3(1.0) * core * 0.22 + glow * wash * 0.3 * haze;
        rgb += glow * shimmer * 0.08;
        rgb += edgeColour * edgeLine * 1.05 + glow * edgeHaze * 0.12;
        return half4(half3(min(rgb, 1.0)), 1.0h) * half(open);
    }
    // On white, light adds to nothing: the colour tints instead, the bubble
    // a pale frosted green, most near the rim, clearer towards the middle.
    float tinted = inside * haze * (0.3 + 0.7 * clamp(wash * 1.5, 0.0, 1.0));
    rgb = mix(rgb, rgb * mix(float3(1.0), glow, 0.22), tinted);
    rgb = mix(rgb, glow, wash * 0.25 * haze);
    rgb = mix(rgb, rim * 0.95, clamp(band * 0.85, 0.0, 1.0));
    rgb = mix(rgb, float3(1.0), core * 0.5);
    rgb = mix(rgb, glow, shimmer * 0.08);
    rgb = mix(rgb, edgeColour * 0.92, clamp(edgeLine * 0.85 + edgeHaze * 0.12, 0.0, 1.0));
    return half4(half3(clamp(rgb, 0.0, 1.0)), 1.0h) * half(open);
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

