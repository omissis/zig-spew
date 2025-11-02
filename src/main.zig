const std = @import("std");
const spew = @import("spew.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var d = spew.Dumper.init(arena.allocator(), spew.DumpOptions{});

    // Scalars

    try d.print(42, .{});

    try d.print(3.14, .{});

    try d.print(0.99999999999999999999999999999999, .{});

    try d.print(true, .{});

    try d.print(false, .{});

    try d.print(null, .{});

    try d.print(undefined, .{});

    // Arrays

    const int_array: [4]u4 = .{ 1, 2, 3, 4 };
    try d.print(int_array, .{});

    const float_array: [5]f64 = .{ 1.1, 2.22, 3.333, 4.4444, 5.55555 };
    try d.print(float_array, .{});

    const bool_array: [4]bool = .{ true, false, true, false };
    try d.print(bool_array, .{});

    const null_array: [4]?u8 = .{ null, null, null, null };
    try d.print(null_array, .{});

    // Pointers

    var int_value: u7 = 123;
    try d.print(&int_value, .{});

    var float_value: f64 = 3.1415;
    try d.print(&float_value, .{});

    var bool_value: bool = true;
    try d.print(&bool_value, .{});

    var str_value = "ciao";
    try d.print(&str_value, .{});

    try d.print("ciao", .{});
    try d.print("ciao", .{
        .options = spew.DumpOptions{
            .string_interpretation = false,
        },
    });

    var int_slice = try arena.allocator().alloc(u4, 5);
    int_slice[0] = 1;
    int_slice[1] = 2;
    int_slice[2] = 3;
    int_slice[3] = 5;
    int_slice[4] = 8;
    try d.print(int_slice, .{});

    var bool_slice = try arena.allocator().alloc(bool, 5);
    bool_slice[0] = true;
    bool_slice[1] = false;
    bool_slice[2] = true;
    bool_slice[3] = false;
    bool_slice[4] = true;
    try d.print(bool_slice, .{});

    var float_slice = try arena.allocator().alloc(f32, 5);
    float_slice[0] = 1.1;
    float_slice[1] = 2.22;
    float_slice[2] = 3.333;
    float_slice[3] = 4.4444;
    float_slice[4] = 5.55555;
    try d.print(float_slice, .{});

    var chars_slice = try arena.allocator().alloc(u8, 5);
    chars_slice[0] = 'c';
    chars_slice[1] = 'i';
    chars_slice[2] = 'a';
    chars_slice[3] = 'o';
    chars_slice[4] = '\n';
    try d.print(chars_slice, .{});
}
