const std = @import("std");
const spew = @import("spew.zig");

test "dump bool" {
    var da = std.heap.DebugAllocator(.{}){};

    const opts = spew.DumpOptions{
        .rendering = .{
            .palette = spew.MonochromaticTheme,
        },
    };

    var dumper = spew.Dumper.init(da.allocator(), opts);

    try std.testing.expectEqualStrings("true", try dumper.dump(true, .{}));
    try std.testing.expectEqualStrings("false", try dumper.dump(false, .{}));
}

test "dump integer" {
    var da = std.heap.DebugAllocator(.{}){};

    const opts = spew.DumpOptions{
        .rendering = .{
            .palette = spew.MonochromaticTheme,
        },
    };

    var dumper = spew.Dumper.init(da.allocator(), opts);

    try std.testing.expectEqualStrings("42", try dumper.dump(42, .{}));
}

test "dump string" {
    var da = std.heap.DebugAllocator(.{}){};

    const opts = spew.DumpOptions{
        .rendering = .{
            .palette = spew.MonochromaticTheme,
        },
    };

    var dumper = spew.Dumper.init(da.allocator(), opts);

    try std.testing.expectEqualStrings(
        "\"42\"",
        try dumper.dump("42", .{}),
    );
}
