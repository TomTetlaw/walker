
Linear_Colour :: struct {
  r, g, b, a: float;
}

rgba :: (f: float) -> Linear_Colour { return .{f, f, f, f}; }

colour_black  :: Linear_Colour.{0, 0, 0, 0};
colour_white  :: Linear_Colour.{1, 1, 1, 1};
colour_red    :: Linear_Colour.{1, 0, 0, 1};
colour_green  :: Linear_Colour.{0, 1, 0, 1};
colour_blue   :: Linear_Colour.{0, 0, 1, 1};
colour_yellow :: Linear_Colour.{1, 1, 0, 1};
colour_pink   :: Linear_Colour.{1, 0, 1, 1};
colour_cyan   :: Linear_Colour.{0, 1, 1, 1};