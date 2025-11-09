const std = @import("std");
const theme = @import("theme.zig");

test "no color write" {
    const color = theme.Color{ .none = theme.NoColor{} };
    var writer = std.Io.Writer.Allocating.init(std.heap.page_allocator);

    try color.write(&writer.writer, "{s}", "hello");

    try std.testing.expectEqualStrings("hello", try writer.toOwnedSlice());
}

test "basic color write" {
    const color = theme.Color{ .basic = theme.BasicColor.RedForeground };
    var writer = std.Io.Writer.Allocating.init(std.heap.page_allocator);

    try color.write(&writer.writer, "{s}", "hello");

    try std.testing.expectEqualStrings("\x1b[31mhello\x1b[0m", try writer.toOwnedSlice());
}

test "extended color write" {
    const color = theme.Color{ .extended = @as(theme.ExtendedColor, 128) };
    var writer = std.Io.Writer.Allocating.init(std.heap.page_allocator);

    try color.write(&writer.writer, "{s}", "hello");

    try std.testing.expectEqualStrings("\x1b[38;5;128mhello\x1b[0m", try writer.toOwnedSlice());
}

test "rgb color write" {
    const color = theme.Color{ .rgb = theme.RgbColor{ .red = 32, .green = 64, .blue = 128 } };
    var writer = std.Io.Writer.Allocating.init(std.heap.page_allocator);

    try color.write(&writer.writer, "{s}", "hello");

    try std.testing.expectEqualStrings("\x1b[38;2;32;64;128mhello\x1b[0m", try writer.toOwnedSlice());
}
