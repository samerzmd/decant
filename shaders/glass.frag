#version 460 core
#include <flutter/runtime_effect.glsl>

// Decant — glass cylinder overlay shader.
//
// Drawn ON TOP of the already-painted liquid (which the Dart CustomPainter
// renders beneath). Outputs mostly-transparent glass shading: a bright left
// rim highlight, a thin moving specular streak, curved cylinder shading and a
// soft right-edge shadow — giving the flat rounded-rect a rounded 3D feel.
//
// Uniforms are set by index from Dart (see glass_painter.dart):
//   0,1 : uSize   (tube rect width, height in logical px)
//   2,3 : uOrigin (tube rect top-left in the same space as FlutterFragCoord)
//   4   : uTime   (seconds, drives the drifting specular)

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

    // Cylinder cross-section: treat x in [0,1] as angle across a half-cylinder.
    // n is the surface "facing" — brightest where it catches light (upper-left).
    float nx = (x - 0.5) * 2.0;            // -1..1
    float curve = sqrt(max(0.0, 1.0 - nx * nx)); // 1 in centre, 0 at edges

    // Broad left highlight (key light from upper-left).
    float leftHi = smoothstep(0.32, 0.0, x) * 0.55;

    // Soft right shadow (occlusion on the far side of the cylinder).
    float rightShade = smoothstep(0.62, 1.0, x) * 0.30;

    // Thin, slightly drifting vertical specular streak near the left third.
    float streakX = 0.22 + 0.03 * sin(uTime * 0.6);
    float streak = smoothstep(0.05, 0.0, abs(x - streakX));
    streak *= (0.45 + 0.25 * curve);
    // Fade the streak near the very top/bottom so it reads as a reflection.
    streak *= smoothstep(0.0, 0.12, y) * smoothstep(1.0, 0.85, y);

    // Faint top glass cap sheen.
    float topSheen = smoothstep(0.10, 0.0, y) * 0.25;

    // Combine into a white highlight amount and a dark shadow amount.
    float hi = clamp(leftHi + streak + topSheen, 0.0, 0.85);
    float shade = rightShade;

    // Compose: additive white highlight, subtractive dark on the right.
    vec3 col = vec3(1.0) * hi;
    float alpha = clamp(hi + shade, 0.0, 0.9);
    // Encode shadow as dark, low-alpha; highlight as bright.
    col = mix(vec3(0.02, 0.04, 0.07), col, hi / max(alpha, 0.0001));

    fragColor = vec4(col * alpha, alpha);
}
