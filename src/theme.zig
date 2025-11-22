const std = @import("std");

pub const ColorFormat = enum { none, basic, extended, rgb };

pub const Color = union(ColorFormat) {
    none: NoColor,
    basic: BasicColor,
    extended: ExtendedColor,
    rgb: RgbColor,

    pub fn write(self: Color, writer: *std.Io.Writer, comptime fmt: []const u8, val: anytype) !void {
        return switch (self) {
            Color.none => {
                const cmft = std.fmt.comptimePrint(
                    "{s}",
                    .{fmt},
                );

                return writer.print(cmft, .{val});
            },
            Color.basic => |c| {
                const cmft = std.fmt.comptimePrint(
                    "\x1b[{{d}}m{s}\x1b[0m",
                    .{fmt},
                );

                return writer.print(cmft, .{ @intFromEnum(c), val });
            },
            Color.extended => |c| {
                const cmft = std.fmt.comptimePrint(
                    "\x1b[38;5;{{d}}m{s}\x1b[0m",
                    .{fmt},
                );

                return writer.print(cmft, .{ c, val });
            },
            Color.rgb => |c| {
                const cmft = std.fmt.comptimePrint(
                    "\x1b[38;2;{{d}};{{d}};{{d}}m{s}\x1b[0m",
                    .{fmt},
                );

                return writer.print(cmft, .{ c.red, c.green, c.blue, val });
            },
        };
    }
};

pub const NoColor = void;

pub const BasicColor = enum(u7) {
    // Standard colors
    BlackForeground = 30,
    BlackBackground = 40,
    RedForeground = 31,
    RedBackground = 41,
    GreenForeground = 32,
    GreenBackground = 42,
    YellowForeground = 33,
    YellowBackground = 43,
    BlueForeground = 34,
    BlueBackground = 44,
    MagentaForeground = 35,
    MagentaBackground = 45,
    CyanForeground = 36,
    CyanBackground = 46,
    WhiteForeground = 37,
    WhiteBackground = 47,
    DefaultForeground = 39,
    DefaultBackground = 49,
    // Bright colors
    BrightBlackForeground = 90,
    BrightBlackBackground = 100,
    BrightRedForeground = 91,
    BrightRedBackground = 101,
    BrightGreenForeground = 92,
    BrightGreenBackground = 102,
    BrightYellowForeground = 93,
    BrightYelloBackgroundw = 103,
    BrightBlueForeground = 94,
    BrightBlueBackground = 104,
    BrightMagentaForeground = 95,
    BrightMagenBackground = 105,
    BrightCyanForeground = 96,
    BrightCyanBackground = 106,
    BrightWhiteForeground = 97,
    BrightWhiteBackground = 107,
};

pub const ExtendedColor = u8;

pub const RgbColor = struct {
    red: u8,
    green: u8,
    blue: u8,
};

pub const BytesRepresentation = enum { hex, dec };

pub const Palette = struct {
    booleans: Color,
    numbers: Color,
    strings: Color,
    bytes: Color,
    empties: Color,
    brackets: Color,
    valueTypes: Color,
    types: Color,
    enums: Color,
    errors: Color,
};

pub const DefaultPalette = Palette{
    .booleans = Color{ .basic = BasicColor.BrightBlueForeground },
    .numbers = Color{ .basic = BasicColor.RedForeground },
    .strings = Color{ .basic = BasicColor.BlueForeground },
    .bytes = Color{ .basic = BasicColor.GreenForeground },
    .empties = Color{ .basic = BasicColor.BrightBlueForeground },
    .brackets = Color{ .basic = BasicColor.MagentaForeground },
    .valueTypes = Color{ .basic = BasicColor.WhiteForeground },
    .types = Color{ .basic = BasicColor.YellowForeground },
    .enums = Color{ .basic = BasicColor.YellowForeground },
    .errors = Color{ .basic = BasicColor.BrightRedForeground },
};

pub const MonochromaticPalette = Palette{
    .booleans = Color{ .none = NoColor{} },
    .numbers = Color{ .none = NoColor{} },
    .strings = Color{ .none = NoColor{} },
    .bytes = Color{ .none = NoColor{} },
    .empties = Color{ .none = NoColor{} },
    .brackets = Color{ .none = NoColor{} },
    .valueTypes = Color{ .none = NoColor{} },
    .types = Color{ .none = NoColor{} },
    .enums = Color{ .none = NoColor{} },
    .errors = Color{ .none = NoColor{} },
};
