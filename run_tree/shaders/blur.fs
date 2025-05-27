
#version 330

in vec2 frag_tex_coord;

out vec4 final_colour;

uniform sampler2D texture0;
uniform vec2 resolution;
uniform float radius;
uniform vec2 dir;

void main() {
    vec2 tex_coord = frag_tex_coord;

    tex_coord.x = frag_tex_coord.x;
    tex_coord.y = 1-frag_tex_coord.y;

	vec4 sum = vec4(0.0);
	vec2 tc = tex_coord;

	float aspect = resolution.x / resolution.y;
	vec2 blur = vec2(radius) / resolution * vec2(aspect);

	float hstep = dir.x;
	float vstep = dir.y;

	sum += texture2D(texture0, vec2(tc.x - 4.0*blur.x*hstep, tc.y - 4.0*blur.y*vstep)) * 0.0162162162;
	sum += texture2D(texture0, vec2(tc.x - 3.0*blur.x*hstep, tc.y - 3.0*blur.y*vstep)) * 0.0540540541;
	sum += texture2D(texture0, vec2(tc.x - 2.0*blur.x*hstep, tc.y - 2.0*blur.y*vstep)) * 0.1216216216;
	sum += texture2D(texture0, vec2(tc.x - 1.0*blur.x*hstep, tc.y - 1.0*blur.y*vstep)) * 0.1945945946;

	sum += texture2D(texture0, vec2(tc.x, tc.y)) * 0.2270270270;

	sum += texture2D(texture0, vec2(tc.x + 1.0*blur.x*hstep, tc.y + 1.0*blur.y*vstep)) * 0.1945945946;
	sum += texture2D(texture0, vec2(tc.x + 2.0*blur.x*hstep, tc.y + 2.0*blur.y*vstep)) * 0.1216216216;
	sum += texture2D(texture0, vec2(tc.x + 3.0*blur.x*hstep, tc.y + 3.0*blur.y*vstep)) * 0.0540540541;
	sum += texture2D(texture0, vec2(tc.x + 4.0*blur.x*hstep, tc.y + 4.0*blur.y*vstep)) * 0.0162162162;

	final_colour = vec4(sum.rgb, 1.0);
}
