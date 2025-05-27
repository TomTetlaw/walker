#version 330

in vec2 frag_tex_coord;

out vec4 final_colour;

uniform sampler2D texture0;
uniform vec2 screen_size;
uniform float enable_psx;

void main() {
    vec2 tex_coord = frag_tex_coord;
    tex_coord.y = 1 - tex_coord.y;

    if (enable_psx > 0) {
    	vec3 colour = texture(texture0, tex_coord).rgb;
        final_colour = vec4(colour, 1);
    } else {
        final_colour = texture(texture0, tex_coord);
    }
}