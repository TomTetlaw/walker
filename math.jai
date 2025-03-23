
turn2deg :: 360.0;
deg2turn :: 1.0 / 360.0;

turn2rad :: TAU;
rad2turn :: 1.0 / TAU;

sin_turns :: (t: float) -> float { return sin(t * turn2rad); }
cos_turns :: (t: float) -> float { return cos(t * turn2rad); }
tan_turns :: (t: float) -> float { return tan(t * turn2rad); }

random_01 :: random_get_zero_to_one;
random_float :: random_get_within_range;

remap :: (x: float, min0: float, max0: float, min1: float, max1: float) -> float {
    return min1 + (x - min0) * (max1 - min1) / (max0 - min0);
}