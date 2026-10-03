#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Pay's effects, after the reference "SIP, send money": the ink a key leaves
// behind the keypad and the sheen in Pay while it is held. (The wave it once
// sent up the screen is the Send Ripple, in SendRipple.metal.)

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

// MARK: Keypad ink

// What a key leaves behind as it lifts, as in the reference. The white
// bubble that sat on the key goes soft and runs down into a tall, frosted
// blob, whiter than the page, with a puff of the accent at its top, and it
// lingers for seconds, so the presses build up behind the pad.
//
// `drops` holds four floats a press: the key's centre in this layer's space,
// seconds since the finger lifted, and a random seed so no two blobs share a
// shape. `radius` is the bubble's; `size` is this layer's, whose edges the
// blobs fade out at.
[[ stitchable ]] half4 PayInk(
    float2 position,
    half4 color,
    device const float *drops,
    int count,
    half4 tint,
    float2 size,
    float radius,
    float whiteStrength,
    float tintStrength,
    float dark,
    float time
) {
    // One slow field for every blob's wavering edge, worked out once a
    // pixel rather than once a blob.
    float warp = fbm3(position * 0.016 + float2(time * 0.05, -time * 0.12)) - 0.5;

    float white = 0.0;
    float accent = 0.0;
    float core = 0.0;
    int pressCount = count / 4;
    for (int i = 0; i < pressCount; i++) {
        float2 key = float2(drops[i * 4], drops[i * 4 + 1]);
        float age = drops[i * 4 + 2];
        float seed = drops[i * 4 + 3];
        if (age <= 0.0) { continue; }
        // Nothing this far from the key.
        if (distance(position, key) > radius * 3.6) { continue; }

        // Most of the change in the first fifth of a second, then a slow
        // drift; fading only after a second and a half.
        float grow = 1.0 - exp(-age * 11.0);
        float life = 1.0 - smoothstep(1.4, 7.0, age);

        // Each blob its own: how wide, how far it runs down, which way it
        // drifts and leans, and the shape of its edge.
        float chanceWidth = fract(seed * 0.123 + 0.5);
        float chanceLength = fract(seed * 0.791 + 0.2);
        float chanceDrift = fract(seed * 0.353 + 0.7);

        // The body: the bubble's circle stretching down into a tall blob,
        // its top staying near the key, leaning either way.
        float2 radii = radius * float2(1.0 + (0.2 + 0.4 * chanceWidth) * grow, 1.0 + (0.55 + 0.75 * chanceLength) * grow);
        float2 center = key + float2((chanceDrift - 0.5) * 0.6 * radius * grow, (radii.y - radius) * 0.7 + 2.5 * age);
        float lean = (fract(seed * 0.37) - 0.5) * 1.1;
        float2 delta = position - center;
        delta = float2(delta.x * cos(lean) - delta.y * sin(lean), delta.x * sin(lean) + delta.y * cos(lean));
        float reach = length(delta / radii);
        float own = valueNoise(delta / radius * 1.3 + seed * 7.3) - 0.5;
        reach += (warp * 0.45 + own * 0.5) * grow + 0.08 * sin(seed * 3.1 + atan2(delta.y, delta.x) * 2.0) * grow;
        // Soft from the moment the bubble goes, softer still a beat later.
        float edge = mix(0.3, 0.42, smoothstep(0.0, 0.15, age));
        float body = 1.0 - smoothstep(1.0 - edge, 1.0 + edge * 0.5, reach);

        // The accent: a puff thrown up and to one side, settling into a
        // haze over the body's top; how far, how big and how strong, its
        // own too.
        float chancePuff = fract(seed * 0.271 + 0.4);
        float angle = -1.5708 + (fract(seed * 0.61) - 0.5) * 2.8;
        float2 puffCenter = key + float2(cos(angle), sin(angle)) * radius * (0.6 + 0.3 * chancePuff + (0.3 + 0.3 * chanceLength) * grow);
        float puffRadius = radius * (0.45 + 0.25 * chanceWidth + (0.6 + 0.5 * chancePuff) * grow);
        float puff = 1.0 - smoothstep(0.0, 1.25, distance(position, puffCenter) / puffRadius + warp * 0.4 + own * 0.3);
        float puffStrength = mix(1.0, 0.55 + 0.3 * chanceDrift, smoothstep(0.05, 0.6, age));
        // And a faint rim of it here and there round the body.
        float rim = body * (1.0 - body) * clamp(0.5 + warp * 2.0, 0.0, 1.0) * grow * 0.35;

        // On black the blob starts as bright as the grey bubble it was and
        // settles to a faint light; on the light page it is white throughout.
        float level = mix(whiteStrength, mix(whiteStrength, 0.3, dark), exp(-age * 9.0));
        white = 1.0 - (1.0 - white) * (1.0 - clamp(body * life * level, 0.0, 1.0));
        accent = 1.0 - (1.0 - accent) * (1.0 - clamp((puff * puffStrength + rim) * life, 0.0, 1.0));
        core = max(core, puff * puff * life);
    }
    // Softly out at the layer's edges rather than cut off.
    float2 edges = min(position, size - position);
    float fade = smoothstep(0.0, 40.0, min(edges.x, edges.y));
    half w = half(white * fade);
    if (dark > 0.5) {
        // On black, light rather than haze: the body a faint warm glow and
        // the accent glowing over it, lighter at its heart. A colour fading
        // into black goes murky (yellow to olive), so where it thins it
        // warms toward embers instead, the way light dies away.
        half a = half(pow(accent, 1.1) * tintStrength * fade);
        half3 ember = tint.rgb * half3(1.0h, 0.7h, 0.55h);
        half3 bright = mix(tint.rgb, half3(1.0h), half(0.15 + 0.25 * core));
        half3 glow = mix(ember, bright, half(smoothstep(0.0, 0.8, accent)));
        half3 haze = mix(half3(1.0h), tint.rgb, 0.12h);
        // Premultiplied.
        return half4(glow * a + haze * w * (1.0h - a), a + w * (1.0h - a));
    }
    // The accent lies under the white, so the body veils it where they
    // meet.
    half a = half(accent * tintStrength * fade) * (1.0h - w * 0.25h);
    // Premultiplied.
    return half4(half3(1.0h) * w + tint.rgb * a, w + a);
}

// MARK: Pay sheen

// Pay while held: lighter, liquid streaks drifting through the button's
// colour, brightest beside the bubble under the finger. White, to lie over
// the button; `size` is the button's, `touch` the finger's x.
[[ stitchable ]] half4 PayButtonSheen(
    float2 position,
    half4 color,
    float2 size,
    float touch,
    float time,
    float strength
) {
    float2 uv = position / size.y;
    float flow = fbm3(float2(uv.x * 1.4 - time * 0.9, uv.y * 2.2 + time * 0.35));
    float streak = smoothstep(0.52, 0.78, flow);
    // Light pooling on both sides of the bubble.
    float side = abs(position.x - touch) / size.y;
    float halo = exp(-pow((side - 0.85) * 2.2, 2.0));
    // Only where the button is.
    half alpha = half(clamp(streak * 0.7 + halo * 0.35 * flow, 0.0, 1.0) * strength) * color.a;
    return half4(half3(alpha), alpha);
}
