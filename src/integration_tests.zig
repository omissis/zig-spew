const std = @import("std");
const spew = @import("root.zig");

test "dump bool" {
    const dumper, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings("true", try dumper.format(arena.allocator(), true));
    try std.testing.expectEqualStrings("false", try dumper.format(arena.allocator(), false));
}

test "dump integer" {
    const dumper, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings("42", try dumper.format(arena.allocator(), 42));
}

test "dump string" {
    const dumper, var arena = setup();
    defer arena.deinit();

    try std.testing.expectEqualStrings(
        "\"42\"",
        try dumper.format(arena.allocator(), "42"),
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
