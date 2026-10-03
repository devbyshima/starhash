#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Pay's effects, after the reference "SIP, send money": the ink a key leaves
// behind the keypad, the sheen in Pay while it is held, and the wave Pay
// sends up the screen.

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
    float time
) {
    // One slow field for every blob's wavering edge, worked out once a
    // pixel rather than once a blob.
    float warp = fbm3(position * 0.016 + float2(time * 0.05, -time * 0.12)) - 0.5;

    float white = 0.0;
    float accent = 0.0;
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

        white = 1.0 - (1.0 - white) * (1.0 - clamp(body * life, 0.0, 1.0));
        accent = 1.0 - (1.0 - accent) * (1.0 - clamp((puff * puffStrength + rim) * life, 0.0, 1.0));
    }
    // Softly out at the layer's edges rather than cut off.
    float2 edges = min(position, size - position);
    float fade = smoothstep(0.0, 40.0, min(edges.x, edges.y));
    // The accent lies under the white, so the body veils it where they
    // meet.
    half w = half(white * whiteStrength * fade);
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

// MARK: Send wave

// What Pay sends up the screen as it lifts. From the button a front climbs
// the screen, slowly at first and then fast. Ahead of it the screen washes
// over with the accent and soft rings of light and accent ride outward,
// bending what is under them and fringing it with colour. On the front a
// band of deeper accent magnifies what it crosses. Behind it the screen is
// white mist, which clears onto the next screen, the content wavering as
// it settles. Runs over snapshots of the screen (`SendRipple` in
// PayEffects.swift).
//
// `reach` is how far the front must go to leave the screen; `clearFrom` is
// the earliest the mist may clear, once the next screen is in; `seed` makes
// each wave's rings its own; `dark` is 1 in dark mode, where the wash and
// mist are dim rather than white.
[[ stitchable ]] half4 PaySendWave(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float2 size,
    float reach,
    float time,
    float clearFrom,
    float seed,
    half4 tint,
    float dark
) {
    float2 delta = position - origin;
    float distance = length(delta);
    float2 direction = distance > 0.001 ? delta / distance : float2(0.0, -1.0);

    // The front: about the button at first, out past the screen's top in
    // just over half a second, slow to start and fast by the end, as the
    // reference's is.
    float progress = clamp(time / 0.55, 0.0, 1.0);
    float front = 70.0 + reach * pow(progress, 2.4);
    // When the front went by here, for what settles behind it.
    float passedAt = 0.55 * pow(clamp((distance - 70.0) / reach, 0.0, 1.0), 1.0 / 2.4);
    float ahead = smoothstep(front - 18.0, front + 26.0, distance);
    float behind = 1.0 - ahead;
    // The front's deeper band shows once it is well up the screen, and is
    // gone as it leaves.
    float onFront = exp(-pow((distance - front + 26.0) / 40.0, 2.0)) * smoothstep(0.12, 0.32, time) * (1.0 - smoothstep(0.46, 0.56, time));
    float ramp = smoothstep(0.0, 0.1, time);

    // Rings about 96pt apart, riding outward, never even: each wavers
    // round its arc, they bunch and spread, some stronger than others, a
    // different set every time.
    float around = atan2(delta.y, delta.x);
    float travelled = distance - 180.0 * time;
    float waver = valueNoise(float2(around * 2.6 + seed, distance * 0.006 - time * 0.9)) - 0.5;
    float bunching = valueNoise(float2(travelled * 0.005 + seed * 3.1, seed)) - 0.5;
    float phase = (travelled + waver * 70.0 + bunching * 90.0) * 6.2832 / 96.0;
    float strength = 0.5 + 0.9 * valueNoise(float2(travelled / 96.0 + seed * 1.7, around * 1.3 + seed));
    float ring = sin(phase) * strength * ahead * ramp;

    // Settling behind the front: a wobble that dies away.
    float settle = behind * (1.0 - smoothstep(0.0, 0.55, time - max(passedAt, clearFrom - 0.3)));
    float2 wobble = float2(sin(position.y * 0.09 + time * 26.0) * 2.6, sin(position.x * 0.05 - time * 20.0) * 3.6) * settle;

    float2 moved = position + direction * (ring * 4.0 - onFront * 14.0) + wobble;
    float split = 0.5 + (abs(cos(phase)) * 1.3 * ahead * ramp) + onFront * 2.5 + settle;
    half4 red = layer.sample(moved + direction * split);
    half4 green = layer.sample(moved);
    half4 blue = layer.sample(moved - direction * split);
    half4 color = half4(red.r, green.g, blue.b, green.a);
    // Softened, as if under water: two more looks across the ring.
    float2 across = float2(-direction.y, direction.x) * (1.0 + 2.0 * ahead * ramp + onFront * 2.0);
    half4 soft = (layer.sample(moved + across) + layer.sample(moved - across)) * 0.5h;
    color = mix(color, soft, 0.5h);

    half3 light = mix(half3(1.0h), half3(0.13h), half(dark));
    half3 wash = mix(light, tint.rgb, mix(0.4h, 0.3h, half(dark)));

    // Ahead: the wash deepening as the front comes, the rings light and
    // accent by turns.
    float washAmount = ahead * ramp * (0.12 + 0.52 * smoothstep(0.04, 0.45, time));
    color.rgb = mix(color.rgb, wash * color.a, half(washAmount));
    color.rgb = mix(color.rgb, light * color.a, half(max(ring, 0.0) * 0.28));
    color.rgb = mix(color.rgb, tint.rgb * color.a, half(max(-ring, 0.0) * 0.12));

    // Behind: mist, white from the button's bubble at first and thinner
    // further up, clearing a beat after the front has gone by, and not
    // before the next screen is in.
    float clearing = max(passedAt, clearFrom);
    float thickness = mix(0.92, 0.5, smoothstep(80.0, reach * 0.75, distance));
    float mist = behind * (1.0 - smoothstep(clearing, clearing + 0.6, time)) * thickness;
    color.rgb = mix(color.rgb, light * color.a, half(mist));

    // The front's deeper band, between the mist and the wash.
    color.rgb = mix(color.rgb, tint.rgb * color.a, half(onFront * 0.45));

    // Flecks of the accent caught in the settling mist, at the screen's
    // edges and down by the button only.
    float2 cell = floor(position / float2(14.0, 6.0));
    float fleck = hash21(cell + floor(time * 24.0) * 13.1);
    float edges = smoothstep(0.7, 1.0, abs(position.x / size.x - 0.5) * 2.0) + 1.0 - smoothstep(0.0, 120.0, abs(position.y - origin.y));
    float flecks = step(1.0 - 0.012 * edges, fleck) * settle * smoothstep(0.3, 0.4, time);
    color.rgb = mix(color.rgb, mix(tint.rgb, light, 0.35h) * color.a, half(flecks * 0.8));
    return color;
}
