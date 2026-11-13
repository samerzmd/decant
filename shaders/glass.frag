#version 460 core
#include <flutter/runtime_effect.glsl>

// Decant — glass cylinder overlay shader.
//
// Drawn ON TOP of the already-painted liquid (which the Dart CustomPainter
// renders beneath). Outputs mostly-transparent glass shading that turns the
// flat rounded rect into a thick-walled glass cylinder:
//   * key light: a broad left highlight and a thin drifting specular streak
//   * Fresnel rims: glass reflects more at grazing angles, so both edges glow
//   * wall thickness: a faint inner edge line just inside each rim
//   * environment bounce: a soft secondary reflection on the right
//   * caustics: light focused through the glass, shimmering at the base
//   * occlusion: a soft shadow on the far side
//
// Uniforms are set by index from Dart (see glass_painter.dart):
//   0,1 : uSize   (tube rect width, height in logical px)
//   2,3 : uOrigin (tube rect top-left in the same space as FlutterFragCoord)
//   4   : uTime   (seconds, drives the drifting specular and caustics)

precision mediump float;

uniform vec2 uSize;
uniform vec2 uOrigin;
uniform float uTime;

out vec4 fragColor;

void main() {
    // Local UV within the tube rect, 0..1.
    vec2 uv = (FlutterFragCoord().xy - uOrigin) / uSize;
    float x = clamp(uv.x, 0.0, 1.0);
    float y = clamp(uv.y, 0.0, 1.0);

    // Cylinder cross-section: x in [0,1] maps across a half-cylinder.
    float nx = (x - 0.5) * 2.0;                     // -1..1
    float curve = sqrt(max(0.0, 1.0 - nx * nx));    // facing: 1 centre, 0 edge

    // Key light from the upper left.
    float leftHi = smoothstep(0.32, 0.0, x) * 0.50;

    // Thin, slightly drifting vertical specular streak near the left third.
    float streakX = 0.22 + 0.03 * sin(uTime * 0.6);
    float streak = smoothstep(0.05, 0.0, abs(x - streakX));
    streak *= (0.45 + 0.25 * curve);
    streak *= smoothstep(0.0, 0.12, y) * smoothstep(1.0, 0.85, y);

    // Fresnel (Schlick-style): reflection rises sharply as the surface turns
    // away from the viewer, giving both rims a crisp glassy glow.
    float fresnel = pow(1.0 - curve, 4.0) * 0.45;

    // Wall thickness: a faint bright line just inside each rim, where light
    // travels through the most glass.
    float wall = smoothstep(0.035, 0.0, abs(x - 0.075))
               + smoothstep(0.035, 0.0, abs(x - 0.925));
    wall *= 0.14 * smoothstep(0.02, 0.1, y);

    // Environment bounce: a soft, wide secondary reflection on the right.
    float bounce = smoothstep(0.11, 0.0, abs(x - 0.80)) * 0.12 * curve;
    bounce *= smoothstep(0.05, 0.25, y) * smoothstep(1.0, 0.7, y);

    // Caustics: light focused by the curved glass pools near the base as
    // slow, shimmering bands.
    float base = smoothstep(0.80, 0.97, y) * smoothstep(1.0, 0.95, y);
    float bands = 0.5 + 0.5 * sin(x * 21.0 + uTime * 1.3)
                      * sin(x * 13.0 - uTime * 0.9 + y * 6.0);
    float caustic = base * bands * curve * 0.22;

    // Faint top glass cap sheen.
    float topSheen = smoothstep(0.10, 0.0, y) * 0.25;

    // Soft shadow on the far side of the cylinder.
    float rightShade = smoothstep(0.62, 1.0, x) * 0.26 * (1.0 - fresnel);

    // Combine into a white highlight amount and a dark shadow amount.
    float hi = clamp(
        leftHi + streak + fresnel + wall + bounce + caustic + topSheen,
        0.0, 0.85);
    float shade = rightShade;

    // Compose: additive white highlight, subtractive dark on the right.
    vec3 col = vec3(1.0) * hi;
    float alpha = clamp(hi + shade, 0.0, 0.9);
    // Encode shadow as dark, low-alpha; highlight as bright.
    col = mix(vec3(0.02, 0.04, 0.07), col, hi / max(alpha, 0.0001));

    fragColor = vec4(col * alpha, alpha);
}
