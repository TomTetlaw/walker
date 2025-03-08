Camera_Base :: struct {
    transform: Mat4;
    view: Mat4;
    projection: Mat4;
    position: Vec3;
    forward: Vec3;
    fov := 0.125;
    near_plane := 0.01;
    far_plane := 5000.0;
}

Flying_Camera :: struct {
    using #as base: Camera_Base;

    FLY_SPEED :: 10.0;
    ROTATION_SPEED :: 0.3;
    ROTATION_SMOOTHING :: 0.3;

    yaw, pitch: float;
    rotation_input: Vec2;

    rotation: Quaternion;
}

flying_camera_apply_input :: (camera: *Flying_Camera, input: Frame_Input) {
    move_speed := Flying_Camera.FLY_SPEED;

    if key_state(input, .LSHIFT) {
        move_speed *= 100.0;
    }

    move_input: Vec3;
    move_input.x = key_state(input, .W) - key_state(input, .S);
    move_input.y = key_state(input, .A) - key_state(input, .D);
    move_input.z = key_state(input, .E) - key_state(input, .Q);
    move_input = rotate(move_input, camera.rotation);
    camera.position += move_input * move_speed * real_delta;

    camera.rotation_input = lerp(camera.rotation_input, input.mouse_delta, Flying_Camera.ROTATION_SMOOTHING);
    delta := camera.rotation_input * camera.ROTATION_SPEED;

    camera.yaw += delta.x*deg2turn;
    camera.pitch += delta.y*deg2turn;
    camera.pitch = clamp(camera.pitch, -0.25, 0.25);

    yaw := quat_from_axis_angle(.{0, 0, -1}, camera.yaw);
    pitch := quat_from_axis_angle(.{0, 1, 0}, camera.pitch);
    camera.rotation = yaw * pitch;

    camera.transform = mat4_translation(camera.position) * mat4_rotation(camera.rotation);
    camera.view = mat4_inverse(camera.transform);
    camera.forward = camera.view[0].xyz;

    camera.projection = mat4_projection(camera.fov, context.aspect_ratio, camera.near_plane, camera.far_plane);
}

#scope_file

#import "Print_Vars";