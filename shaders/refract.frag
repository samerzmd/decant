#version 460 core
#include <flutter/runtime_effect.glsl>

// Decant — liquid seen through a glass cylinder.
//
// The tube painter draws the liquid into an offscreen image of the cavity,
// then draws it back through this shader across the whole tube. Each pixel
// is a ray from the viewer entering a liquid-filled cylinder: it bends at
// the surface (Snell's law) and we sample the liquid where it crosses the
// cylinder's axis plane. That magnifies the middle of the column and squeezes
// the edges, lets the liquid fill part of the thick glass wall, and splits
// colours slightly at the edges, where the bend is strongest.
//
// Uniforms, set by index from Dart (see tube_painter.dart):
//   0,1   : uSize  (tube width, height in logical px, local coordinates)
//   2..5  : uInner (cavity left, top, width, height; the image covers it)
//   6     : uIor   (refractive index, about 1.33 for water)
//   7     : uEdge  (where the liquid appears to end, as a fraction of the
//                   tube's half width; between the cavity and the outer wall)
//   sampler 0 : uLiquid (the liquid image, premultiplied)

precision mediump float;

uniform vec2 uSize;
uniform vec4 uInner;
uniform float uIor;
uniform float uEdge;
uniform sampler2D uLiquid;

out vec4 fragColor;

// For a ray entering a unit cylinder at nx (-1..1 across it), where it
// crosses the plane through the axis, also -1..1.
float lens(float nx, float ior) {
    float a = clamp(abs(nx), 0.0, 0.9999);
    float incident = asin(a);
    float refracted = asin(a / ior);
    float x = a - sqrt(1.0 - a * a) * tan(incident - refracted);
    return sign(nx) * x;
}

vec4 liquidAt(float x, float y) {
    vec2 uv = (vec2(x, y) - uInner.xy) / uInner.zw;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        return vec4(0.0);
    }
    return texture(uLiquid, uv);
}

void main() {
    vec2 p = FlutterFragCoord().xy;
    float hw = uSize.x * 0.5;
    float nx = (p.x - hw) / hw;
    if (abs(nx) >= 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Scale so a ray at uEdge lands exactly on the cavity wall.
    float cavityHalf = uInner.z * 0.5;
    float scale = (cavityHalf / hw) / lens(uEdge, uIor);
    float centre = uInner.x + cavityHalf;

    // Red bends a little less than blue (dispersion).
    float spread = 0.012;
    vec4 g = liquidAt(centre + lens(nx, uIor) * hw * scale, p.y);
    float r = liquidAt(centre + lens(nx, uIor - spread) * hw * scale, p.y).r;
    float b = liquidAt(centre + lens(nx, uIor + spread) * hw * scale, p.y).b;
    vec4 col = vec4(r, g.g, b, g.a);
    // Stay valid premultiplied colour where the channels came from
    // different samples.
    col.rgb = min(col.rgb, vec3(col.a));

    // Less light gets through at grazing angles.
    col *= 1.0 - 0.3 * pow(abs(nx), 6.0);
    fragColor = col;
}
