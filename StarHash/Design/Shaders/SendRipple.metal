#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// The Send Ripple, kept for later: the wave Pay used to send up the screen
// as someone was chosen to pay. Nothing draws it now; see SendRipple.swift.

// MARK: Noise

// The same noise as PayEffects.metal, which keeps its own copy.

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

// MARK: Send Ripple

// What Pay sent up the screen as it lifted. From the button a front climbs
// the screen, slowly at first and then fast. Ahead of it the screen washes
// over with the accent and soft rings of light and accent ride outward,
// bending what is under them and fringing it with colour. On the front a
// band of deeper accent magnifies what it crosses. Behind it the screen is
// white mist, which clears onto the next screen, the content wavering as
// it settles. Runs over snapshots of the screen (`SendRipple` in
// SendRipple.swift).
//
// `reach` is how far the front must go to leave the screen; `clearFrom` is
// the earliest the mist may clear, once the next screen is in; `seed` makes
// each wave's rings its own; `dark` is 1 in dark mode, which has a palette
// of its own: light on dark rather than a pale wash.
[[ stitchable ]] half4 SendRipple(
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

    // The mist clears a beat after the front has gone by, and not before
    // the next screen is in; it is thickest by the finger.
    float clearing = max(passedAt, clearFrom);
    float thickness = mix(0.92, 0.5, smoothstep(80.0, reach * 0.75, distance));
    float mist = behind * (1.0 - smoothstep(clearing, clearing + 0.6, time)) * thickness;

    // Flecks of the accent caught in the settling mist, at the screen's
    // edges and down by the button only.
    float2 cell = floor(position / float2(14.0, 6.0));
    float fleck = hash21(cell + floor(time * 24.0) * 13.1);
    float edges = smoothstep(0.7, 1.0, abs(position.x / size.x - 0.5) * 2.0) + 1.0 - smoothstep(0.0, 120.0, abs(position.y - origin.y));
    float flecks = step(1.0 - 0.012 * edges, fleck) * settle * smoothstep(0.3, 0.4, time);

    if (dark > 0.5) {
        // On black, light on dark rather than a pale wash: a colour faded
        // into black goes murky (yellow to olive), so the accent comes only
        // as bright light, in narrow bands, and the rest is shade.
        half3 glow = mix(tint.rgb, half3(1.0h), 0.35h);

        // Ahead: the screen dimming as the front comes, a breath of the
        // accent in the shade, and thin bright crests riding out.
        float dim = ahead * ramp * (0.1 + 0.38 * smoothstep(0.04, 0.45, time));
        color.rgb = mix(color.rgb, tint.rgb * 0.1h * color.a, half(dim));
        float crest = pow(max(ring, 0.0), 2.0);
        color.rgb = mix(color.rgb, glow * color.a, half(crest * 0.4));

        // Behind: the next screen comes up out of the dark.
        color.rgb = mix(color.rgb, half3(0.02h) * color.a, half(mist * 0.95));

        // The front, a bright narrow line of the accent, there from the
        // start so the finger's ripple shows at once.
        float line = exp(-pow((distance - front + 18.0) / 22.0, 2.0)) * smoothstep(0.0, 0.12, time) * (1.0 - smoothstep(0.46, 0.56, time));
        color.rgb = mix(color.rgb, glow * color.a, half(line * 0.55));

        color.rgb = mix(color.rgb, glow * color.a, half(flecks * 0.8));
        return color;
    }

    half3 light = half3(1.0h);
    half3 wash = mix(light, tint.rgb, 0.4h);

    // Ahead: the wash deepening as the front comes, the rings light and
    // accent by turns.
    float washAmount = ahead * ramp * (0.12 + 0.52 * smoothstep(0.04, 0.45, time));
    color.rgb = mix(color.rgb, wash * color.a, half(washAmount));
    color.rgb = mix(color.rgb, light * color.a, half(max(ring, 0.0) * 0.28));
    color.rgb = mix(color.rgb, tint.rgb * color.a, half(max(-ring, 0.0) * 0.12));

    // Behind: mist, white from the finger's bubble at first and thinner
    // further up.
    color.rgb = mix(color.rgb, light * color.a, half(mist));

    // The front's deeper band, between the mist and the wash.
    color.rgb = mix(color.rgb, tint.rgb * color.a, half(onFront * 0.45));

    color.rgb = mix(color.rgb, mix(tint.rgb, light, 0.35h) * color.a, half(flecks * 0.8));
    return color;
}
