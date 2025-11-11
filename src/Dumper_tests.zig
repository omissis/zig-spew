const std = @import("std");
const theme = @import("theme.zig");
const Dumper = @import("Dumper.zig");

test "dump bool" {
    const d, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings(
        "bool true",
        try d.format(arena.allocator(), true),
    );
    try std.testing.expectEqualStrings(
        "bool false",
        try d.format(arena.allocator(), false),
    );
}

test "dump integer" {
    const d, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings(
        "comptime_int 42",
        try d.format(arena.allocator(), 42),
    );
}

test "dump string" {
    const d, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings(
        "*const [2:0]u8 \"42\"",
        try d.format(arena.allocator(), "42"),
    );

    // Do not interpret strings: show bytes list instead
    const d_no_str = Dumper.Dumper{
        .options = .{
            .palette = theme.MonochromaticPalette,
            .string_interpretation = false,
        },
    };

    try std.testing.expectEqualStrings(
        "*const [4:0]u8 [0x63, 0x69, 0x61, 0x6f]",
        try d_no_str.format(arena.allocator(), "ciao"),
    );
}

test "dump float" {
    const d, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings(
        "comptime_float 3.14",
        try d.format(arena.allocator(), 3.14),
    );
}

test "dump null" {
    const d, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings(
        "@TypeOf(null) null",
        try d.format(arena.allocator(), null),
    );
}

test "dump undefined" {
    const d, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings(
        "@TypeOf(undefined) undefined",
        try d.format(arena.allocator(), undefined),
    );
}

test "dump arrays" {
    const d, var arena = setup();
    defer arena.deinit();

    const int_array: [4]u4 = .{ 1, 2, 3, 4 };
    try std.testing.expectEqualStrings(
        "[4]u4 [1, 2, 3, 4]",
        try d.format(arena.allocator(), int_array),
    );

    const bool_array: [4]bool = .{ true, false, true, false };
    try std.testing.expectEqualStrings(
        "[4]bool [true, false, true, false]",
        try d.format(arena.allocator(), bool_array),
    );
}

test "dump slices" {
    const d, var arena = setup();
    defer arena.deinit();

    var int_slice = try arena.allocator().alloc(u4, 5);
    int_slice[0] = 1;
    int_slice[1] = 2;
    int_slice[2] = 3;
    int_slice[3] = 5;
    int_slice[4] = 8;

    try std.testing.expectEqualStrings(
        "[]u4 [1, 2, 3, 5, 8]",
        try d.format(arena.allocator(), int_slice),
    );
}

test "dump u8 bytes" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Default: bytes interpreted as hex
    const d_hex = Dumper.Dumper{ .options = .{ .palette = theme.MonochromaticPalette } };
    try std.testing.expectEqualStrings(
        "u8 0xf",
        try d_hex.format(arena.allocator(), @as(u8, 15)),
    );

    // Decimal representation for bytes
    const d_dec = Dumper.Dumper{
        .options = .{
            .palette = theme.MonochromaticPalette,
            .bytes_representation = theme.BytesRepresentation.dec,
        },
    };
    try std.testing.expectEqualStrings(
        "u8 15",
        try d_dec.format(arena.allocator(), @as(u8, 15)),
    );
}

test "dump pointers" {
    const d, var arena = setup();
    defer arena.deinit();

    var int_value: u7 = 123;
    try std.testing.expectEqualStrings(
        "*u7 123",
        try d.format(arena.allocator(), &int_value),
    );

    var float_value: f64 = 3.1415;
    try std.testing.expectEqualStrings(
        "*f64 3.1415",
        try d.format(arena.allocator(), &float_value),
    );

    var bool_value: bool = true;
    try std.testing.expectEqualStrings(
        "*bool true",
        try d.format(arena.allocator(), &bool_value),
    );
}

test "dump struct (pretty and compact)" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const Currency = struct {
        Name: []const u8,
        Symbol: []const u8,
    };
    const Money = struct {
        Amount: u32,
        Currency: Currency,
    };

    const m = Money{
        .Amount = 1000,
        .Currency = .{ .Name = "Euro", .Symbol = "€" },
    };

    const d_pretty = Dumper.Dumper{
        .options = .{
            .palette = theme.MonochromaticPalette,
            .structs_pretty_print = true,
        },
    };
    const expected_pretty = try std.fmt.allocPrint(
        arena.allocator(),
        "{s} {{\n" ++
            "    Amount: u32 1000,\n" ++
            "    Currency: {s} {{\n" ++
            "        Name: []const u8 \"Euro\",\n" ++
            "        Symbol: []const u8 \"€\"\n" ++
            "    }}\n" ++
            "}}",
        .{ @typeName(Money), @typeName(Currency) },
    );
    try std.testing.expectEqualStrings(
        expected_pretty,
        try d_pretty.format(arena.allocator(), m),
    );

    const d_compact = Dumper.Dumper{
        .options = .{
            .palette = theme.MonochromaticPalette,
            .structs_pretty_print = false,
        },
    };
    const expected_compact = try std.fmt.allocPrint(
        arena.allocator(),
        "{s} {{ Amount: u32 1000, Currency: {s} {{ Name: []const u8 \"Euro\", Symbol: []const u8 \"€\" }} }}",
        .{ @typeName(Money), @typeName(Currency) },
    );
    try std.testing.expectEqualStrings(
        expected_compact,
        try d_compact.format(arena.allocator(), m),
    );
}

fn setup() struct { Dumper.Dumper, std.heap.ArenaAllocator } {
    return .{
        Dumper.Dumper{
            .options = .{
                .palette = theme.MonochromaticPalette,
            },
        },
        std.heap.ArenaAllocator.init(std.heap.page_allocator),
    };
}
