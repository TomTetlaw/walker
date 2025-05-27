#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

out vec4 clip_position;
out vec2 frag_tex_coord;
out vec3 frag_colour;
out vec3 frag_normal;
out vec3 frag_position;

uniform mat4 view_to_clip;
uniform mat4 local_to_world;
uniform vec3 albedo_colour;

void main()
{
    frag_colour = vertexColor.rgb * albedo_colour;
    frag_tex_coord = vertexTexCoord;
    frag_normal = vertexNormal;

    clip_position = view_to_clip * local_to_world * vec4(vertexPosition, 1.0);
    frag_position = (local_to_world * vec4(vertexPosition, 1.0)).xyz;

    gl_Position = clip_position;
}