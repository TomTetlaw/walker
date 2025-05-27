#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;

out vec2 frag_tex_coord;

uniform mat4 ortho;

void main()
{
    frag_tex_coord = vertexTexCoord;
    gl_Position = ortho * vec4(vertexPosition, 1.0);
}