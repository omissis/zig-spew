const std = @import("std");
const spew = @import("dumper.zig");

test "dump bool" {
    var da = std.heap.DebugAllocator(.{}){};

    const opts = spew.DumpOptions{};
    var dumper = spew.Dumper.init(da.allocator(), opts);

    try std.testing.expectEqualStrings("true", try dumper.dump(bool, true, spew.DumpContext{}));
    try std.testing.expectEqualStrings("false", try dumper.dump(bool, false, spew.DumpContext{}));
}

test "dump integer" {
    var da = std.heap.DebugAllocator(.{}){};

    const opts = spew.DumpOptions{};
    var dumper = spew.Dumper.init(da.allocator(), opts);

    try std.testing.expectEqualStrings("42", try dumper.dump(i32, 42, spew.DumpContext{}));
}

test "dump string" {
    const ctx = spew.DumpContext{};
    const opts = spew.DumpOptions{};
    const expected = "\"42\"";

    var da = std.heap.DebugAllocator(.{}){};
    var dumper = spew.Dumper.init(da.allocator(), opts);

    try std.testing.expectEqualStrings(
        expected,
        try dumper.dump([]const u8, "42", ctx),
    );
}
