#import bevy_render::globals::Globals;
#import bevy_render::view::View;
#import bevy_sprite::mesh2d_vertex_output::VertexOutput

@group(0) @binding(0) var<uniform> u_view: View;
@group(0) @binding(1) var<uniform> u_globals: Globals;

@group(2) @binding(0) var<uniform> u_is_editor_dark_mode: i32;
@group(2) @binding(1) var u_debug_uv_texture: texture_2d<f32>;
@group(2) @binding(2) var u_debug_uv_texture_sampler: sampler;

struct FragmentOutput {
    @location(0) color: vec4<f32>,
    @builtin(frag_depth) frag_depth: f32,
}

// Call `gamma_to_linear` in the fragment shader on the final color.
fn gamma_to_linear(nonlinear: vec4<f32>) -> vec4<f32> {
    let cutoff = step(nonlinear, vec4<f32>(0.04045));
    let higher = pow((nonlinear + vec4<f32>(0.055)) / vec4<f32>(1.055), vec4<f32>(2.4));
    let lower = nonlinear / vec4<f32>(12.92);
    return mix(higher, lower, cutoff);
}

@fragment
fn fragment(in: VertexOutput) -> FragmentOutput {
    var out: FragmentOutput;

    if (u_is_editor_dark_mode == 0) {
        out.color = vec4(1.0, 1.0, 1.0, 1.0);
    } else {
        out.color = vec4(24.0 / 255.0, 25.0 / 255.0, 36.0 / 255.0, 1.0);
    }

    out.color = gamma_to_linear(out.color);
    out.frag_depth = 0.0;

    return out;
}

