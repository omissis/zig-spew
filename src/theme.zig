const std = @import("std");

const StringType = enum {
    MutableSliceOfBytes,
    ZeroTerminatedStringSlice,
};

const String = union(StringType) {
    MutableSliceOfBytes: []u8,
    ZeroTerminatedStringSlice: [:0]const u8,
};

const ColorFormat = enum { none, basic, extended, rgb };

const Color = union(ColorFormat) {
    none: NoColor,
    basic: BasicColor,
    extended: ExtendedColor,
    rgb: RgbColor,

    fn format(self: Color, allocator: std.mem.Allocator, val: String) ![]u8 {
        const inner_value = switch (val) {
            .MutableSliceOfBytes => val.MutableSliceOfBytes,
            .ZeroTerminatedStringSlice => val.ZeroTerminatedStringSlice,
        };

        return switch (self) {
            Color.none => {
                return try std.fmt.allocPrint(
                    allocator,
                    "{s}",
                    .{inner_value},
                );
            },
            Color.basic => |c| {
                return try std.fmt.allocPrint(
                    allocator,
                    "\x1b[{d}m{s}\x1b[0m",
                    .{ @intFromEnum(c), inner_value },
                );
            },
            Color.extended => |c| {
                return try std.fmt.allocPrint(
                    allocator,
                    "\x1b[38;5;{d}m{s}\x1b[0m",
                    .{ c, inner_value },
                );
            },
            Color.rgb => |c| {
                return try std.fmt.allocPrint(
                    allocator,
                    "\x1b[38;2;{d};{d};{d}m{s}\x1b[0m",
                    .{ c.red, c.green, c.blue, inner_value },
                );
            },
        };
    }
};

const NoColor = void;

const BasicColor = enum(u7) {
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

const ExtendedColor = u8;

const RgbColor = struct {
    red: u8,
    green: u8,
    blue: u8,
};

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    options: RenderOptions,

    pub fn init(allocator: std.mem.Allocator, options: RenderOptions) Renderer {
        return .{
            .allocator = allocator,
            .options = options,
        };
    }

    pub fn formatString(self: *Renderer, val: anytype, ctx: RenderContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        const str_val = String{ .ZeroTerminatedStringSlice = "\"" ++ val ++ "\"" };

        return try opts.palette.strings.format(self.allocator, str_val);
    }

    pub fn formatByte(self: *Renderer, val: anytype, ctx: RenderContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        const bytes = switch (opts.bytes_representation) {
            BytesRepresentation.hex => try std.fmt.allocPrint(self.allocator, "0x{x}", .{val}),
            BytesRepresentation.dec => try std.fmt.allocPrint(self.allocator, "{d}", .{val}),
        };
        const str_val = String{ .MutableSliceOfBytes = bytes };

        return try opts.palette.bytes.format(self.allocator, str_val);
    }

    pub fn formatInt(self: *Renderer, val: anytype, ctx: RenderContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        const str_val = String{
            .MutableSliceOfBytes = try std.fmt.allocPrint(self.allocator, "{d}", .{val}),
        };

        return try opts.palette.numbers.format(self.allocator, str_val);
    }

    pub fn formatFloat(self: *Renderer, val: anytype, ctx: RenderContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        const str_val = String{
            .MutableSliceOfBytes = try std.fmt.allocPrint(self.allocator, "{d}", .{val}),
        };

        return try opts.palette.numbers.format(self.allocator, str_val);
    }

    pub fn formatBoolean(self: *Renderer, val: anytype, ctx: RenderContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        const str_val = String{ .ZeroTerminatedStringSlice = if (val) "true" else "false" };

        return try opts.palette.booleans.format(self.allocator, str_val);
    }

    pub fn formatNull(self: *Renderer, ctx: RenderContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        const str_val = String{ .ZeroTerminatedStringSlice = "null" };

        return try opts.palette.empties.format(self.allocator, str_val);
    }

    pub fn formatUndefined(self: *Renderer, ctx: RenderContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        const str_val = String{ .ZeroTerminatedStringSlice = "undefined" };

        return try opts.palette.empties.format(self.allocator, str_val);
    }
};

pub const RenderOptions = struct {
    palette: Palette = DefaultPalette,
    decimal_places: u6 = 3,
    decimal_min_width: u6 = 0,
    hex_padding: u6 = 0,
    string_interpretation: bool = true, // whether to interpret arrays and slices of u8 as strings
    bytes_interpretation: bool = true, // whether to interpret u8 as bytes instead of decimals
    bytes_representation: BytesRepresentation = .hex, // wheter to represent bytes as decimals or hexadecimals
};

const BytesRepresentation = enum { hex, dec };

pub const RenderContext = struct {
    cur_depth: u32 = 0,
    options: ?RenderOptions = null,

    pub fn incDepth(self: RenderContext) RenderContext {
        return RenderContext{
            .cur_depth = self.cur_depth + 1,
        };
    }
};

pub const Palette = struct {
    booleans: Color,
    numbers: Color,
    strings: Color,
    bytes: Color,
    empties: Color,
    keywords: Color,
};

pub const DefaultPalette = Palette{
    .booleans = Color{ .basic = BasicColor.BrightBlueForeground },
    .numbers = Color{ .basic = BasicColor.RedForeground },
    .strings = Color{ .basic = BasicColor.BlueForeground },
    .bytes = Color{ .basic = BasicColor.GreenForeground },
    .empties = Color{ .basic = BasicColor.BrightBlueForeground },
    .keywords = Color{ .basic = BasicColor.MagentaForeground },
};

pub const MonochromaticPalette = Palette{
    .booleans = Color{ .none = NoColor{} },
    .numbers = Color{ .none = NoColor{} },
    .strings = Color{ .none = NoColor{} },
    .bytes = Color{ .none = NoColor{} },
    .empties = Color{ .none = NoColor{} },
    .keywords = Color{ .none = NoColor{} },
};
