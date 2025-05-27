
#version 330

in vec2 frag_tex_coord;

out vec4 final_colour;

uniform sampler2D texture0;

void main() {
    vec2 tex_coord = frag_tex_coord;
    tex_coord.y = 1 - tex_coord.y;

	final_colour = vec4(texture(texture0, tex_coord).rgb, 1.0);
}