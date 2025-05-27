
Camera_Base :: struct {
    transform: Mat4;
    view: Mat4;
    projection: Mat4;
    position: V3;
    forward: V3;
    fov := 0.25;
    near_plane := 0.01;
    far_plane := 5000.0;
}

Flying_Camera :: struct {
    using #as base: Camera_Base;

    FLY_SPEED :: 2.4;
    ROTATION_SPEED :: 0.3;
    ROTATION_SMOOTHING :: 0.3;

    yaw, pitch: float;
    rotation_input: V2;

    rotation: Quaternion;
}

flying_camera_apply_input :: (camera: *Flying_Camera) {
    move_speed := Flying_Camera.FLY_SPEED;

    if IsKeyDown(cast (s32) KeyboardKey.LEFT_SHIFT) {
        move_speed *= 100.0;
    }

    move_input: V3;
    move_input.x = cast(float) IsKeyDown(cast (s32) KeyboardKey.W) - cast(float) IsKeyDown(cast (s32) KeyboardKey.S);
    move_input.y = cast(float) IsKeyDown(cast (s32) KeyboardKey.A) - cast(float) IsKeyDown(cast (s32) KeyboardKey.D);
    move_input.z = cast(float) IsKeyDown(cast (s32) KeyboardKey.E) - cast(float) IsKeyDown(cast (s32) KeyboardKey.Q);
    move_input = rotate(move_input, camera.rotation);
    camera.position += move_input * move_speed * real_delta;

    d := GetMouseDelta();
    mouse_delta := V2.{d.x, d.y};

    camera.rotation_input = lerp(camera.rotation_input, mouse_delta, Flying_Camera.ROTATION_SMOOTHING);
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

Player_Camera :: struct {
    using #as base: Camera_Base;

    WALK_SPEED :: 4.7;
    RUN_SPEED :: 9.6;
    STAND_HEIGHT :: 6.0;

    CROUCH_SPEED :: 2.5;
    CROUCH_HEIGHT :: 3.0;

    ROTATION_SPEED :: 0.3;
    ROTATION_SMOOTHING :: 0.3;

    yaw, pitch: float;
    rotation_input: V2;

    rotation: Quaternion;

    velocity: V2;
    ground_pos: V3;
}

player_camera_apply_input :: (camera: *Player_Camera) {
    move_speed := Player_Camera.WALK_SPEED;
    eye_height := Player_Camera.STAND_HEIGHT;

    if IsKeyDown(cast(s32) KeyboardKey.LEFT_CONTROL) {
        move_speed = Player_Camera.CROUCH_SPEED;
        eye_height = Player_Camera.CROUCH_HEIGHT;
    } else {
        if IsKeyDown(cast(s32) KeyboardKey.LEFT_SHIFT) {
            move_speed = Player_Camera.RUN_SPEED;
        }
    }

    move_input: V2;
    move_input.x = cast(float) IsKeyDown(cast(s32) KeyboardKey.W) - cast(float) IsKeyDown(cast(s32) KeyboardKey.S);
    move_input.y = cast(float) IsKeyDown(cast(s32) KeyboardKey.A) - cast(float) IsKeyDown(cast(s32) KeyboardKey.D);
    move_input = normalize(move_input);
    move_input = rotate(move_input, camera.yaw);

    move := move_input * move_speed * game_delta;
    camera.velocity = move_input * move_speed;
    camera.position = v3(camera.ground_pos.xy + move, camera.ground_pos.z + eye_height);

    d := GetMouseDelta();
    mouse_delta := V2.{d.x, d.y};

    camera.rotation_input = lerp(camera.rotation_input, mouse_delta, Player_Camera.ROTATION_SMOOTHING);
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