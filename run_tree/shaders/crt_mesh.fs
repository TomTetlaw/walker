#version 330

in vec4 clip_position;
in vec2 frag_tex_coord;
in vec3 frag_colour;
in vec3 frag_normal;
in vec3 frag_position;

uniform sampler2D albedo_texture;
uniform sampler2D crt_bezel_mask;
uniform float enable_lighting;
uniform float time;
uniform float bezel_glow;

out vec4 final_colour;

void main()
{
    float ambient = 0.3;

    vec3 L = normalize(-frag_position);
    float diffuse = max(dot(frag_normal, L), 0.0) * .5;

    vec3 camera_position = vec3(0, 0, 0);
    vec3 camera_forward = vec3(1, 0, 0);

    vec3 light_dir = normalize(vec3(0, 0, .25));
    vec3 R = reflect(-light_dir, frag_normal);

    float specular = pow(max(dot(camera_position - frag_position, R), 0.0), 2);
    specular *= .11;

    vec2 tex_coord = frag_tex_coord;
    tex_coord.x = 1 - frag_tex_coord.y;
    tex_coord.y = 1 - frag_tex_coord.x;

    float lighting = 1.0;
    if (enable_lighting > 0) {
        lighting = ambient + diffuse + specular;
        lighting *= .25;
    }

    if (bezel_glow > 0) {
        vec2 tc = tex_coord;
        tc.x = 1 - tex_coord.y;
        tc.y = tex_coord.x;
        vec3 tex = texture(albedo_texture, tc).rgb * texture(crt_bezel_mask, tc).rgb;

        float glow = 1;

        final_colour = vec4(lighting*frag_colour + tex*glow, 1);
    } else {
        vec3 tex = texture(albedo_texture, tex_coord).rgb;
        final_colour = vec4(lighting * frag_colour * tex, 1);
    }
}