#version 330

in vec4 clip_position;
in vec2 frag_tex_coord_0;
in vec2 frag_tex_coord_1;
in vec4 frag_colour;
in float fog_factor;

uniform sampler2D albedo_texture;
uniform vec2 screen_size;
uniform float enable_psx;
uniform float enable_fog;

out vec4 final_colour;

void main()
{
    vec2 tex_coord;

    if (enable_psx > 0) {
        tex_coord = frag_tex_coord_1 / clip_position.w;
        tex_coord = mix(tex_coord, frag_tex_coord_0, .5);
    } else {
        tex_coord = frag_tex_coord_0;
    }

    vec4 albedo = texture(albedo_texture, tex_coord);
    vec4 colour = albedo * frag_colour;

    if (enable_psx > 0) {
        ivec4 dither[4] = ivec4[4](
            ivec4(-4,  0, -3,  1),
            ivec4( 2, -2,  3, -1),
            ivec4(-3,  1, -4,  0),
            ivec4( 3, -1,  2, -2)
        );

        vec2 screen_pos = (clip_position.xy / clip_position.w) * .5 + .5;
        ivec2 pixel_coord = ivec2(screen_pos * screen_size);

        float values = floor(pow(2, 5));
        vec3 banded = floor(colour.rgb * values) / values;

        uvec3 truncated = uvec3((banded * 255) + vec3(dither[pixel_coord.y % 4][pixel_coord.x % 4]));

        uint mask = uint(0xf8);
        truncated = clamp(truncated & mask, uint(0), mask);

        colour.rgb = vec3(truncated) / 248.0;
    }

    vec4 fog_colour = vec4(.5, .5, .5, 1);
    final_colour = mix(colour, fog_colour, fog_factor);
}