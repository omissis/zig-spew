const std = @import("std");
const spew = @import("spew");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const d = spew.Dumper{};

    // Scalars

    try d.print(42);

    try d.print(3.14);

    try d.print(0.99999999999999999999999999999999);

    try d.print(true);

    try d.print(false);

    try d.print(null);

    try d.print(undefined);

    // Arrays

    const int_array: [4]u4 = .{ 1, 2, 3, 4 };
    try d.print(int_array);

    const float_array: [5]f64 = .{ 1.1, 2.22, 3.333, 4.4444, 5.55555 };
    try d.print(float_array);

    const bool_array: [4]bool = .{ true, false, true, false };
    try d.print(bool_array);

    const null_array: [4]?u8 = .{ null, null, null, null };
    try d.print(null_array);

    // Pointers

    var int_value: u7 = 123;
    try d.print(&int_value);

    var float_value: f64 = 3.1415;
    try d.print(&float_value);

    var bool_value: bool = true;
    try d.print(&bool_value);

    var str_value = "ciao";
    try d.print(&str_value);

    try d.print("ciao");

    const d2 = spew.Dumper{ .options = .{ .string_interpretation = false } };

    try d2.print("ciao");

    var int_slice = try arena.allocator().alloc(u4, 5);
    int_slice[0] = 1;
    int_slice[1] = 2;
    int_slice[2] = 3;
    int_slice[3] = 5;
    int_slice[4] = 8;
    try d.print(int_slice);

    var bool_slice = try arena.allocator().alloc(bool, 5);
    bool_slice[0] = true;
    bool_slice[1] = false;
    bool_slice[2] = true;
    bool_slice[3] = false;
    bool_slice[4] = true;
    try d.print(bool_slice);

    var float_slice = try arena.allocator().alloc(f32, 5);
    float_slice[0] = 1.1;
    float_slice[1] = 2.22;
    float_slice[2] = 3.333;
    float_slice[3] = 4.4444;
    float_slice[4] = 5.55555;
    try d.print(float_slice);

    var chars_slice = try arena.allocator().alloc(u8, 5);
    chars_slice[0] = 'c';
    chars_slice[1] = 'i';
    chars_slice[2] = 'a';
    chars_slice[3] = 'o';
    chars_slice[4] = '\n';
    try d.print(chars_slice);

    // Structs

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
        .Currency = .{
            .Name = "Euro",
            .Symbol = "€",
        },
    };

    try spew.dump(m);

    const d3 = spew.Dumper{ .options = .{ .structs_pretty_print = false } };

    try d3.print(m);

    try d.print(exampleStruct);

    try d.print(exampleEnum.ciao);
}

const exampleStruct = struct {
    name: []u8,
    description: []u8,
    active: bool,
};

const exampleEnum = enum(u8) {
    hello,
    world,
    ciao,
    mondo,
};
