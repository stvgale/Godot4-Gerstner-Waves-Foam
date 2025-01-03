shader_type spatial;

const float TWO_PI = 6.28318530718;
const float GRAVITY_SQRT = 3.130495168; 
uniform float wavelength1 : hint_range(0.1, 100.0) = 10.0;
uniform float amplitude1 : hint_range(0.0, 5.0) = 1.0;
uniform float steepness1 : hint_range(0.0, 1.0) = 0.1;
uniform float speed1 : hint_range(0.0, 10.0) = 1.0;
uniform vec2 wave_direction1 = vec2(1.0, 0.0);

uniform float wavelength2 : hint_range(0.1, 100.0) = 8.0;
uniform float amplitude2 : hint_range(0.0, 5.0) = 0.5;
uniform float steepness2 : hint_range(0.0, 1.0) = 0.08;
uniform float speed2 : hint_range(0.0, 10.0) = 0.5;
uniform vec2 wave_direction2 = vec2(0.8, 0.6);

uniform sampler2D displacement_texture_1;
uniform sampler2D displacement_texture_2;
uniform sampler2D normal_texture_1;
uniform sampler2D normal_texture_2;
uniform float displacement_scale = 1.0;
uniform float displacement_height = 1.0;
uniform vec2 displacement_velocity_1 = vec2(0.1, 0.0);
uniform vec2 displacement_velocity_2 = vec2(0.1, 0.0);

uniform vec3 wave_albedo: source_color = vec3(0.325, 0.807, 0.971);

uniform float foam_start = 1.0;
uniform float foam_end = 2.0;

varying vec2 animated_uv_1;
varying vec2 animated_uv_2;
varying float wave_height;

vec3 gerstner_wave(vec3 pos, vec2 dir, float amp, float k, float w, float steep, float time) {
    vec2 d = normalize(dir);
    float phi = k * dot(d, pos.xz) - w * time;
    float Q = steep * amp * k;

    return vec3(Q * cos(phi) * d.x, amp * sin(phi), Q * cos(phi) * d.y);
}

void gerstner_wave_derivatives(
    vec3 world_pos,
    vec2 direction,
    float amplitude,
    float wavelength,
    float steepness,
    float speed,
    float time,
    inout vec3 dpdx,
    inout vec3 dpdz
) {
    vec2 d = normalize(direction);
    float k = 2.0 * PI / wavelength;
    float w = sqrt(9.8 * k);
    float phi = k * (d.x * world_pos.x + d.y * world_pos.z) - w * time * speed;

    float Q = steepness * amplitude * k;
    float sin_phi = sin(phi);
    float cos_phi = cos(phi);

    float dphidx = k * d.x;
    float dphidz = k * d.y;

    float dXdx = Q * d.x * (-sin_phi) * dphidx;
    float dXdz = Q * d.x * (-sin_phi) * dphidz;

    float dYdx = (amplitude) * cos_phi * dphidx;
    float dYdz = (amplitude) * cos_phi * dphidz;

    float dZdx = Q * d.y * (-sin_phi) * dphidx;
    float dZdz = Q * d.y * (-sin_phi) * dphidz;

    dpdx += vec3(dXdx, dYdx, dZdx);
    dpdz += vec3(dXdz, dYdz, dZdz);
}

vec3 calculate_gerstner_normal(vec3 world_pos, float time) {
    vec3 dpdx = vec3(1.0, 0.0, 0.0);
    vec3 dpdz = vec3(0.0, 0.0, 1.0);

    gerstner_wave_derivatives(world_pos, wave_direction1, amplitude1, wavelength1, steepness1, speed1, time, dpdx, dpdz);
    gerstner_wave_derivatives(world_pos, wave_direction2, amplitude2, wavelength2, steepness2, speed2, time, dpdx, dpdz);

    return normalize(cross(dpdz, dpdx));
}

void vertex() {
    vec3 world_pos = VERTEX.xyz;

    animated_uv_1 = fract((UV + displacement_velocity_1 * TIME) / displacement_scale);
    animated_uv_2 = fract((UV + displacement_velocity_2 * TIME) / displacement_scale);

    float tex_disp_1 = texture(displacement_texture_1, animated_uv_1).r * displacement_height;
    float tex_disp_2 = texture(displacement_texture_2, animated_uv_2).r * displacement_height;

    float k1 = TWO_PI / wavelength1;
    float w1 = GRAVITY_SQRT * k1;
    float k2 = TWO_PI / wavelength2;
    float w2 = GRAVITY_SQRT * k2;

    vec3 wave1 = gerstner_wave(world_pos, wave_direction1, amplitude1, k1, w1, steepness1, TIME);
    vec3 wave2 = gerstner_wave(world_pos, wave_direction2, amplitude2, k2, w2, steepness2, TIME);

    float combined_displacement = tex_disp_1 + tex_disp_2 + wave1.y + wave2.y - displacement_height;
    VERTEX.y += combined_displacement;
    VERTEX.xz += wave1.xz + wave2.xz;
    wave_height = tex_disp_1 + tex_disp_2 + wave1.y + wave2.y;
    vec3 gerstner_normal = calculate_gerstner_normal(world_pos, TIME);
    vec3 normal_sample_1 = (texture(normal_texture_1, animated_uv_1).rgb * 2.0 - 1.0) * displacement_height;
    vec3 normal_sample_2 = (texture(normal_texture_2, animated_uv_2).rgb * 2.0 - 1.0) * displacement_height;

    vec3 combined_normal = normalize(gerstner_normal + normal_sample_1 + normal_sample_2);

    vec3 normal_local = normalize((inverse(transpose(MODEL_MATRIX)) * vec4(combined_normal, 0.0)).xyz);
    NORMAL = normal_local;
}
void fragment() {
    float foam_factor = smoothstep(foam_start, foam_end, abs(wave_height));
    vec3 foam_color = vec3(1.0);
    ALBEDO = mix(wave_albedo, foam_color, foam_factor);
}