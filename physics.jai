
simulate_physics :: () {
    accumulator += game_delta;

    sim_time := game_time;
    while accumulator >= physics_delta {
        for entity_list {
            it.p0 = it.p;
        }

        integrate(sim_time, physics_delta);

        sim_time += physics_delta;
        accumulator -= physics_delta;
    }

    alpha := accumulator / physics_delta;
    for entity_list {
        it.draw_p = lerp(it.p0, it.p, alpha);
    }
}

#scope_file

integrate :: (st: float, dt: float) {
    for entity_list {
        it.dp += it.ddp * dt;
        it.p += it.dp * dt;
    }
}

physics_delta :: 1.0 / 6.0;
accumulator: float;