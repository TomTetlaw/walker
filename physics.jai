
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
        it.phys_p = lerp(it.p0, it.p, alpha);
    }
}

#scope_file

integrate :: (st: float, dt: float) {
    for entity_list {
        if !(it.flags & .NO_PHYSICS) {
            it.p += it.dp * dt;
        }
    }
}

physics_delta :: 1.0 / 60.0;
accumulator: float;