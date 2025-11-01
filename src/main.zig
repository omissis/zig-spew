const std = @import("std");
const spew = @import("spew.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var d = spew.Dumper.init(arena.allocator(), spew.DumpOptions{});

    const arr_int: [4]u4 = .{ 1, 2, 3, 4 };
    const arr_float: [5]f64 = .{ 1.1, 2.22, 3.333, 4.4444, 5.55555 };
    const arr_bool: [4]bool = .{ true, false, true, false };
    const arr_null: [4]?u8 = .{ null, null, null, null };

    try d.print(42, .{});
    try d.print(3.14, .{});
    try d.print(0.99999999999999999999999999999999, .{});
    try d.print(true, .{});
    try d.print(false, .{});
    try d.print(null, .{});
    try d.print(undefined, .{});
    try d.print(arr_int, .{});
    try d.print(arr_float, .{});
    try d.print(arr_bool, .{});
    try d.print(arr_null, .{});

    try d.print("ciao", .{});
    try d.print("ciao", .{
        .options = spew.RenderOptions{
            .string_interpretation = false,
        },
    });
}
