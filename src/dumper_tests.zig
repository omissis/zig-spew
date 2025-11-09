const std = @import("std");
const spew = @import("spew");

test "dump bool" {
    const dumper, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings(
        "true",
        try dumper.format(arena.allocator(), true),
    );
    try std.testing.expectEqualStrings(
        "false",
        try dumper.format(arena.allocator(), false),
    );
}

test "dump integer" {
    const dumper, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings(
        "42",
        try dumper.format(arena.allocator(), 42),
    );
}

test "dump string" {
    const dumper, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings(
        "\"42\"",
        try dumper.format(arena.allocator(), "42"),
    );

    // Do not interpret strings: show bytes list instead
    const d_no_str = spew.Dumper{
        .options = .{
            .palette = spew.MonochromaticTheme,
            .string_interpretation = false,
        },
    };
    try std.testing.expectEqualStrings(
        "[0x63, 0x69, 0x61, 0x6f]",
        try d_no_str.format(arena.allocator(), "ciao"),
    );
}

test "dump float" {
    const dumper, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings(
        "3.14",
        try dumper.format(arena.allocator(), 3.14),
    );
}

test "dump null" {
    const dumper, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings(
        "null",
        try dumper.format(arena.allocator(), null),
    );
}

test "dump undefined" {
    const dumper, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings(
        "undefined",
        try dumper.format(arena.allocator(), undefined),
    );
}

test "dump arrays" {
    const dumper, var arena = setup();
    defer arena.deinit();

    const int_array: [4]u4 = .{ 1, 2, 3, 4 };
    try std.testing.expectEqualStrings(
        "[1, 2, 3, 4]",
        try dumper.format(arena.allocator(), int_array),
    );

    const bool_array: [4]bool = .{ true, false, true, false };
    try std.testing.expectEqualStrings(
        "[true, false, true, false]",
        try dumper.format(arena.allocator(), bool_array),
    );
}

test "dump slices" {
    const dumper, var arena = setup();
    defer arena.deinit();

    var int_slice = try arena.allocator().alloc(u4, 5);
    int_slice[0] = 1;
    int_slice[1] = 2;
    int_slice[2] = 3;
    int_slice[3] = 5;
    int_slice[4] = 8;

    try std.testing.expectEqualStrings(
        "[1, 2, 3, 5, 8]",
        try dumper.format(arena.allocator(), int_slice),
    );
}

test "dump u8 bytes" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Default: bytes interpreted as hex
    const d_hex = spew.Dumper{ .options = .{ .palette = spew.MonochromaticTheme } };
    try std.testing.expectEqualStrings(
        "0xf",
        try d_hex.format(arena.allocator(), @as(u8, 15)),
    );

    // Decimal representation for bytes
    const d_dec = spew.Dumper{
        .options = .{
            .palette = spew.MonochromaticTheme,
            .bytes_representation = spew.BytesRepresentation.dec,
        },
    };
    try std.testing.expectEqualStrings(
        "15",
        try d_dec.format(arena.allocator(), @as(u8, 15)),
    );
}

test "dump pointers" {
    const dumper, var arena = setup();
    defer arena.deinit();

    var int_value: u7 = 123;
    try std.testing.expectEqualStrings(
        "123",
        try dumper.format(arena.allocator(), &int_value),
    );

    var float_value: f64 = 3.1415;
    try std.testing.expectEqualStrings(
        "3.1415",
        try dumper.format(arena.allocator(), &float_value),
    );

    var bool_value: bool = true;
    try std.testing.expectEqualStrings(
        "true",
        try dumper.format(arena.allocator(), &bool_value),
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

    const d_pretty = spew.Dumper{
        .options = .{
            .palette = spew.MonochromaticTheme,
            .structs_pretty_print = true,
        },
    };
    const expected_pretty = try std.fmt.allocPrint(
        arena.allocator(),
        "{s} {{\n" ++
            "    Amount: 1000,\n" ++
            "    Currency: {s} {{\n" ++
            "        Name: \"Euro\",\n" ++
            "        Symbol: \"€\"\n" ++
            "    }}\n" ++
            "}}",
        .{ @typeName(Money), @typeName(Currency) },
    );
    try std.testing.expectEqualStrings(
        expected_pretty,
        try d_pretty.format(arena.allocator(), m),
    );

    const d_compact = spew.Dumper{
        .options = .{
            .palette = spew.MonochromaticTheme,
            .structs_pretty_print = false,
        },
    };
    const expected_compact = try std.fmt.allocPrint(
        arena.allocator(),
        "{s} {{ Amount: 1000, Currency: {s} {{ Name: \"Euro\", Symbol: \"€\" }} }}",
        .{ @typeName(Money), @typeName(Currency) },
    );
    try std.testing.expectEqualStrings(
        expected_compact,
        try d_compact.format(arena.allocator(), m),
    );
}

fn setup() struct { spew.Dumper, std.heap.ArenaAllocator } {
    return .{
        spew.Dumper{
            .options = .{
                .palette = spew.MonochromaticTheme,
            },
        },
        std.heap.ArenaAllocator.init(std.heap.page_allocator),
    };
}
