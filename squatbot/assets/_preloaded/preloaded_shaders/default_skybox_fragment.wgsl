#import teg_skybox::skybox_vertex_output::SkyboxVertexOutput
#import bevy_pbr::utils::coords_to_viewport_uv
#import bevy_render::globals::Globals;
#import bevy_render::maths::{PI, PI_2, HALF_PI};
#import bevy_render::view::View;

@group(0) @binding(0) var<uniform> u_view: View;
@group(0) @binding(1) var<uniform> u_globals: Globals;

@group(1) @binding(0) var<uniform> u_is_editor_dark_mode: i32;
@group(1) @binding(1) var u_debug_uv_texture: texture_2d<f32>;
@group(1) @binding(2) var u_debug_uv_texture_sampler: sampler;

fn coords_to_ray_direction(position: vec2<f32>, viewport: vec4<f32>) -> vec3<f32> {
    // Using world positions of the fragment and camera to calculate a ray direction
    // breaks down at large translations. This code only needs to know the ray direction.
    // The ray direction is along the direction from the camera to the fragment position.
    // In view space, the camera is at the origin, so the view space ray direction is
    // along the direction of the fragment position - (0,0,0) which is just the
    // fragment position.
    // Use the position on the near clipping plane to avoid -inf world position
    // because the far plane of an infinite reverse projection is at infinity.
    let view_position_homogeneous = u_view.view_from_clip * vec4(
        coords_to_viewport_uv(position, viewport) * vec2(2.0, -2.0) + vec2(-1.0, 1.0),
        1.0,
        1.0,
    );
    let view_ray_direction = view_position_homogeneous.xyz / view_position_homogeneous.w;
    // Transforming the view space ray direction by the view matrix, transforms the
    // direction to world space. Note that the w element is set to 0.0, as this is a
    // vector direction, not a position, That causes the matrix multiplication to ignore
    // the translations from the view matrix.
    let ray_direction = (u_view.world_from_view * vec4(view_ray_direction, 0.0)).xyz;

    return normalize(ray_direction);
}

fn viewport_position_to_spherical_uv(viewport_position: vec2<f32>) -> vec2<f32> {
    let ray_direction = coords_to_ray_direction(viewport_position, u_view.viewport);
    let uv_x = atan2(ray_direction.x, ray_direction.z) / PI;
    let uv_y = asin(ray_direction.y) / HALF_PI;
    return vec2<f32>(1.0 - ((uv_x - -1.0) / 2.0), (uv_y - 1.0) / -2.0);
}

fn srgb_to_linear(srgb: vec3<f32>) -> vec3<f32> {
    return pow(srgb, vec3<f32>(2.2));
}

fn linear_to_srgb(linear: vec3<f32>) -> vec3<f32> {
    return pow(linear, vec3<f32>(1.0 / 2.2));
}

// Gradient noise from Jorge Jimenez's presentation:
// http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
fn gradient_noise(uv: vec2<f32>) -> f32 {
    let magic = vec3<f32>(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(uv, magic.xy)));
}

@fragment
fn fragment(in: SkyboxVertexOutput) -> @location(0) vec4<f32> {
    var color0 = vec3<f32>(0.0);
    var color1 = vec3<f32>(0.0);
    if (u_is_editor_dark_mode == 0) {
        color0 = vec3<f32>(39.0 / 255.0, 38.0 / 255.0, 127.0 / 255.0);
        color1 = vec3<f32>(176.0 / 255.0, 124.0 / 255.0, 143.0 / 255.0);
    } else {
        color0 = vec3<f32>(59.0 / 255.0, 33.0 / 255.0, 111.0 / 255.0);
        color1 = vec3<f32>(103.0 / 255.0, 32.0 / 255.0, 67.0 / 255.0);
    }

    var out = vec4<f32>(0.0, 0.0, 0.0, 0.0);
    let uv = in.position.xy / u_view.viewport.zw;
    // let uv = viewport_position_to_spherical_uv(in.position.xy);

    // Calculate interpolation factor with vector projection.
    let a = vec2<f32>(0.5, 0.0);
    let b = vec2<f32>(0.5, 1.0);
    let ba = b - a;
    var t = dot(uv - a, ba) / dot(ba, ba);

    // Saturate and apply smoothstep to the factor.
    t = smoothstep(0.0, 1.0, clamp(t, 0.0, 1.0));

    // Convert color from linear to sRGB color space (=gamma encode).
    var color = mix(
        linear_to_srgb(color0),
        linear_to_srgb(color1),
        t);

    color = srgb_to_linear(color);

    // Add gradient noise to reduce banding.
    let noise_amount = (1.0 / 255.0) * gradient_noise(in.position.xy) - (0.5 / 255.0);
    color += noise_amount;

    out = vec4<f32>(color, 1.0);

    return out;
}
