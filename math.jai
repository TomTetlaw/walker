
turn2deg :: 360.0;
deg2turn :: 1.0 / 360.0;

turn2rad :: TAU;
rad2turn :: 1.0 / TAU;

sin_turns :: (t: float) -> float { return sin(t * turn2rad); }
cos_turns :: (t: float) -> float { return cos(t * turn2rad); }
tan_turns :: (t: float) -> float { return tan(t * turn2rad); }