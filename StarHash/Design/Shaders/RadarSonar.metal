#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// People Nearby's radar (`PeopleNearbyRadar`): the whole page water,
// printed in dots as a sonar screen in a submarine film (the owner's ask).
// On each heartbeat a ring rolls out from the owner's photo, slowly, every
// ring the same broad crest at the same speed, so they come evenly spaced.
// The water is lit as before, each crest's near slope bright and its far
// slope in shade, and the light is drawn as an ordered 1-bit dither: dense
// dots where the water catches it, few or none where it doesn't, over a
// faint grain that flickers. Rings soften only as they leave the page.
// `Heartbeat` in PeopleNearbyRadar.swift keeps the same clock and the same
// rings, so the photo swells and the faces bob as each passes.

// A 4x4 ordered-dither threshold, 0 to 1, for the dot at `cell`.
static float bayer(float2 cell) {
    int x = int(fmod(cell.x, 4.0));
    int y = int(fmod(cell.y, 4.0));
    const int matrix[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
    return (float(matrix[y * 4 + x]) + 0.5) / 16.0;
}

static float sonarHash(float2 p) {
    p = fract(p * float2(443.897, 441.423));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}

// One ring's slope `x` points from its crest: a smooth bump `width` wide,
// rising toward the crest and falling past it.
static float ringSlope(float x, float height, float width) {
    float bell = exp(-(x * x) / (2.0 * width * width));
    return -height * x / (width * width) * bell;
}

[[ stitchable ]] half4 RadarSonar(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float period,
    float speed,
    float origin,
    float motion,
    half4 tint
) {
    float2 middle = size * 0.5;
    float2 delta = position - middle;
    float r = length(delta);
    float2 direction = r > 0.001 ? delta / r : float2(0.0, 1.0);
    // The farthest corner: rings soften away as they reach it.
    float corner = length(middle);

    float slope = 0.0;
    if (motion > 0.0) {
        // Each ring starts under the photo, two widths in, so its crest
        // leaves the photo's edge on the beat itself, as the photo swells:
        // the photo sends it, with no gap between the two.
        float width = 30.0;
        float start = origin - 2.0 * width;
        float lead = (origin - start) / speed;
        float clock = time + lead;
        float beat = floor(clock / period);
        int alive = int(ceil((corner - start) / (speed * period))) + 1;
        for (int back = 0; back < 10; back++) {
            if (back >= alive) { break; }
            float age = clock - (beat - float(back)) * period;
            float crest = start + age * speed;
            float leaving = 1.0 - smoothstep(corner * 0.72, corner, crest);
            slope += ringSlope(r - crest, 14.0, width) * leaving;
        }
    }

    // The surface's tilt, and two slow, faint swells crossing, so still
    // water is never quite still.
    float2 tilt = direction * slope;
    float2 swellA = float2(0.041, 0.019);
    float2 swellB = float2(-0.016, 0.047);
    tilt += motion * 0.3 * (swellA * cos(dot(position, swellA) + time * 0.8) + swellB * cos(dot(position, swellB) - time * 0.6));

    float3 normal = normalize(float3(-tilt, 1.0));
    float3 toLight = normalize(float3(-0.35, -0.75, 0.55));
    float3 bounced = reflect(-toLight, normal);
    float glint = pow(max(bounced.z, 0.0), 70.0);
    // How much more light than flat water: the near slopes and the glints.
    float facing = dot(normal, toLight) - toLight.z;

    // A touch brighter round the photo, the same light everywhere else.
    float out = clamp((r - origin) / (corner - origin), 0.0, 1.0);
    // Right up to the photo's edge, with no fade in past it.
    float reach = mix(1.0, 0.75, out) * smoothstep(origin * 0.92, origin * 1.0, r);
    float light = clamp(0.06 + facing * 2.4 + glint * 1.2, 0.0, 1.0) * reach;
    // The screen's faint grain, flickering a few times a second.
    float frame = floor(time * 8.0) * motion;
    light += 0.04 * sonarHash(floor(position / 2.0) + frame * 13.7);

    // Dots: each 2pt cell lit or not against its threshold.
    float dot = step(bayer(floor(position / 2.0)), light);
    half alpha = half(dot) * tint.a;
    return half4(tint.rgb * alpha, alpha);
}
