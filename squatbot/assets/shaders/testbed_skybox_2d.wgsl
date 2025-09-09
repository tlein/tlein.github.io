// Credit to https://www.shadertoy.com/view/lscGDr
// Original description:
//
// Demonstrates high-quality and proper gamma-corrected color gradient.
//
// Does interpolation in linear color space, mixing colors using smoothstep function.
// Also adds some gradient noise to reduce banding.
//
// References:
// http://blog.johnnovak.net/2016/09/21/what-every-coder-should-know-about-gamma/
// https://developer.nvidia.com/gpugems/GPUGems3/gpugems3_ch24.html
// http://loopit.dk/banding_in_games.pdf
//
// This shader is dedicated to public domain.
//

#import bevy_sprite::{
    mesh2d_bindings::mesh,
    mesh2d_functions,
}
#import bevy_render::globals::Globals;
#import bevy_render::view::View;
#import bevy_render::maths::{affine3_to_square, mat2x4_f32_to_mat3x3_unpack}
#import bevy_sprite::mesh2d_vertex_output::VertexOutput

@group(0) @binding(0) var<uniform> u_view: View;
@group(0) @binding(1) var<uniform> u_globals: Globals;

@group(2) @binding(0) var<uniform> u_is_editor_dark_mode: i32;
@group(2) @binding(1) var u_debug_uv_texture: texture_2d<f32>;
@group(2) @binding(2) var u_debug_uv_texture_sampler: sampler;

// Call `linear_to_gamma` on colors sampled from textures and from colors passed in the uniform as Color (or else convert to Vec4 in the uniform).
fn linear_to_gamma(linear: vec4<f32>) -> vec4<f32> {
    let cutoff = step(linear, vec4<f32>(0.0031308));
    let higher = vec4<f32>(1.055) * pow(linear, vec4(1.0 / 2.4)) - vec4(0.055);
    let lower = linear * vec4<f32>(12.92);
    return mix(higher, lower, cutoff);
}

// Call `gamma_to_linear` in the fragment shader on the final color.
fn gamma_to_linear(nonlinear: vec4<f32>) -> vec4<f32> {
    let cutoff = step(nonlinear, vec4<f32>(0.04045));
    let higher = pow((nonlinear + vec4<f32>(0.055)) / vec4<f32>(1.055), vec4<f32>(2.4));
    let lower = nonlinear / vec4<f32>(12.92);
    return mix(higher, lower, cutoff);
}

// Gradient noise from Jorge Jimenez's presentation:
// http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
fn gradient_noise(uv: vec2<f32>) -> f32 {
    let magic = vec3<f32>(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(uv, magic.xy)));
}

struct FragmentOutput {
    @location(0) color: vec4<f32>,
    @builtin(frag_depth) frag_depth: f32,
}

@fragment
fn fragment(in: VertexOutput) -> FragmentOutput {
    var out: FragmentOutput;

    let COLOR0 = vec3<f32>( 59.0 / 255.0,  50.0 / 255.0, 130.0 / 255.0);
    let COLOR1 = vec3<f32>(159.0 / 255.0, 113.0 / 255.0, 141.0 / 255.0);

    let a = vec2<f32>(0.5, -0.2); // First gradient point.
    let b = vec2<f32>(0.5,  1.2); // Second gradient point.

    // Calculate interpolation factor with vector projection.
    let ba = b - a;
    var t: f32;
    t = dot(in.uv.xy - a, ba) / dot(ba, ba);

    // Saturate and apply smoothstep to the factor.
    t = smoothstep(0.0, 1.0, clamp(t, 0.0, 1.0));
    // Interpolate.
    var color: vec3<f32>;
    color = mix(COLOR0.xyz, COLOR1.xyz, t);

    // Add gradient noise to reduce banding.
    color += (1.0 / 255.0) * gradient_noise(u_view.viewport.zw) - (0.5 / 255.0);

    out.color = vec4(color, 1.0);
    out.color = gamma_to_linear(out.color);

    out.frag_depth = 0.0;

    return out;
}

