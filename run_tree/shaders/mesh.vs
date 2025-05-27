#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

out vec4 clip_position;
out vec2 frag_tex_coord_0;
out vec2 frag_tex_coord_1;
out vec4 frag_colour;
out float fog_factor;

uniform mat4 view_to_clip;
uniform mat4 world_to_view;
uniform mat4 local_to_world;

uniform float texture_scale;

uniform vec2 screen_size;
uniform float enable_psx;
uniform float enable_fog;

void main()
{
    frag_colour = vertexColor;

    clip_position = view_to_clip * world_to_view * local_to_world * vec4(vertexPosition, 1.0);

    if (enable_psx > 0) {
        vec2 screen_pos = (clip_position.xy / clip_position.w) * screen_size;
        screen_pos = floor(screen_pos);
        clip_position.xy = (screen_pos / screen_size) * clip_position.w;
    }

    frag_tex_coord_0 = vertexTexCoord * texture_scale;
    frag_tex_coord_1 = vertexTexCoord * clip_position.w * texture_scale;

    vec4 view_position = world_to_view * local_to_world * vec4(vertexPosition, 1.0);
    float dist = length(view_position);

    if (enable_fog > 0) {
        float fog_start = 30.0;
        float fog_end = 100.0;
        fog_factor = 1.0 - clamp((fog_end - dist) / (fog_end - fog_start), 0.0, 1.0);
    } else {
        fog_factor = 0;
    }

    gl_Position = clip_position;
}