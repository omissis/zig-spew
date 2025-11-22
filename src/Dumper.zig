// Imports

const std = @import("std");
const theme = @import("theme.zig");

// Types

pub const Dumper = @This();

pub const Options = struct {
    indent_size: u32 = 4,
    indent_char: u8 = ' ',
    max_depth: u32 = 10,
    palette: theme.Palette = theme.DefaultPalette,
    // decimal_places: u6 = 3, // for future usage
    // decimal_min_width: u6 = 0, // for future usage
    // hex_padding: u6 = 0, // for future usage
    print_types: bool = true, // whether to display type information besides the value
    string_interpretation: bool = true, // whether to interpret arrays and slices of u8 as strings
    bytes_interpretation: bool = true, // whether to interpret u8 as bytes instead of decimals
    bytes_representation: theme.BytesRepresentation = .hex, // wheter to represent bytes as decimals or hexadecimals
    structs_pretty_print: bool = true, // whether to print structs with newlines and indentation or not
};

const Context = struct {
    cur_depth: u16 = 0,
    has_list_parent: bool = false, // whether the parent is a list type
    parent_type: ?type = null,
    print_value: bool = true,

    pub fn incDepth(self: Context) Context {
        var new = self;

        new.cur_depth += 1;

        return new;
    }

    pub fn withParentType(self: Context, typ: type) Context {
        var new = self;

        new.parent_type = typ;

        return new;
    }

    pub fn withListParent(self: Context) Context {
        var new = self;

        new.has_list_parent = true;

        return new;
    }

    pub fn withoutValue(self: Context) Context {
        var new = self;

        new.print_value = false;

        return new;
    }
};

// Properties

options: Options = .{},

// Dumper's own functions

pub fn print(self: *const Dumper, value: anytype) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buf);

    try self.write(&writer.interface, value, .{});
    try writer.interface.writeAll("\n");

    try writer.interface.flush();
}

pub fn format(self: *const Dumper, allocator: std.mem.Allocator, value: anytype) ![]u8 {
    var allocating = std.Io.Writer.Allocating.init(allocator);
    defer allocating.deinit();

    const writer = &allocating.writer;

    try self.write(writer, value, .{});
    try writer.flush();

    return allocating.toOwnedSlice();
}

pub fn write(self: *const Dumper, writer: *std.Io.Writer, value: anytype, ctx: Context) !void {
    const type_of = @TypeOf(value);
    const type_info = @typeInfo(type_of);

    // std.debug.print("VALUE: {any}\n", .{value});
    // std.debug.print("TYPE OF: {any}\n", .{type_of});
    // std.debug.print("TYPE INFO: {any}\n", .{type_info});

    switch (type_info) {
        .bool => {
            return self.formatBoolean(writer, value, ctx);
        },
        .int => {
            if (self.options.bytes_interpretation) {
                if (type_info.int.signedness == .unsigned and type_info.int.bits == 8) {
                    return self.formatByte(writer, value, ctx);
                }
            }

            return self.formatInt(writer, value, ctx);
        },
        .comptime_int => {
            return self.formatInt(writer, value, ctx);
        },
        .float, .comptime_float => {
            return self.formatFloat(writer, value, ctx);
        },
        .null => {
            return self.formatNull(writer, ctx);
        },
        .undefined => {
            return self.formatUndefined(writer, ctx);
        },
        .array => {
            return self.formatList(writer, value, value.len, ctx);
        },
        .optional => {
            if (value == null) {
                return self.formatNull(writer, ctx);
            }

            return self.write(writer, value.?, ctx.incDepth().withParentType(type_of));
        },
        .pointer => {
            const child_type_info = @typeInfo(type_info.pointer.child);

            // std.debug.print("PTR: {any}\n", .{type_info.pointer});
            // std.debug.print("CHILD_TYPE_INFO: {any}\n", .{child_type_info});

            switch (type_info.pointer.size) {
                .one => {
                    switch (child_type_info) {
                        .array => {
                            switch (child_type_info.array.child) {
                                u8 => {
                                    if (self.options.string_interpretation) {
                                        return self.formatString(writer, value, ctx);
                                    }
                                },
                                else => {
                                    // TODO: implement this
                                },
                            }
                        },
                        else => {
                            // TODO: implement this
                        },
                    }

                    return self.write(writer, value.*, ctx.incDepth().withParentType(type_of));
                },
                .slice => {
                    switch (child_type_info) {
                        .int => {
                            if (child_type_info.int.signedness == .unsigned and child_type_info.int.bits == 8) {
                                if (self.options.string_interpretation) {
                                    return self.formatString(writer, value, ctx);
                                }
                            }
                        },
                        else => {
                            // TODO: implement this
                        },
                    }

                    return self.formatList(writer, value, value.len, ctx);
                },
                else => {
                    // TODO: implement this
                },
            }
        },
        .@"struct" => {
            return self.formatStruct(writer, value, ctx);
        },
        .type => {
            return self.formatType(writer, value, ctx);
        },
        .@"enum", .enum_literal => {
            return self.formatEnum(writer, value, ctx);
        },
        .error_union => {
            return self.formatErrorUnion(writer, value, ctx);
        },
        .error_set => {
            return self.formatErrorSet(writer, value, ctx);
        },
        .@"fn" => {
            return self.formatFunction(writer, value, ctx);
        },
        .void => {
            return self.formatVoid(writer, value, ctx);
        },
        // TODO: implement all the following types
        //.noreturn
        //.@"union"
        //.@"opaque"
        //.frame
        //.@"anyframe"
        .vector => {
            return self.formatList(writer, value, type_info.vector.len, ctx);
        },
        else => {
            // TODO: implement this
        },
    }

    // std.debug.print("Value {any} has unsupported type: {any}\n", .{ value, type_of });
    // std.debug.print("Type Info: {any}\n", .{type_info});

    return;
}

fn formatString(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: Context) !void {
    try self.writeValueType(writer, val, ctx);

    return self.options.palette.strings.write(writer, "\"{s}\"", val);
}

fn formatByte(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: Context) !void {
    try self.writeValueType(writer, val, ctx);

    return switch (self.options.bytes_representation) {
        theme.BytesRepresentation.hex => try self.options.palette.bytes.write(writer, "0x{x}", val),
        theme.BytesRepresentation.dec => try self.options.palette.bytes.write(writer, "{d}", val),
    };
}

fn formatInt(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: Context) !void {
    try self.writeValueType(writer, val, ctx);

    return self.options.palette.numbers.write(writer, "{d}", val);
}

fn formatFloat(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: Context) !void {
    try self.writeValueType(writer, val, ctx);

    return self.options.palette.numbers.write(writer, "{d}", val);
}

fn formatBoolean(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: Context) !void {
    try self.writeValueType(writer, val, ctx);

    return try self.options.palette.booleans.write(writer, "{s}", if (val) "true" else "false");
}

fn formatNull(self: *const Dumper, writer: *std.Io.Writer, ctx: Context) !void {
    try self.writeValueType(writer, null, ctx);

    return try self.options.palette.empties.write(writer, "{s}", "null");
}

fn formatUndefined(self: *const Dumper, writer: *std.Io.Writer, ctx: Context) !void {
    try self.writeValueType(writer, undefined, ctx);

    return try self.options.palette.empties.write(writer, "{s}", "undefined");
}

fn formatBrackets(self: *const Dumper, writer: *std.Io.Writer, val: anytype) !void {
    return try self.options.palette.brackets.write(writer, "{s}", val);
}

fn formatList(self: *const Dumper, writer: *std.Io.Writer, val: anytype, len: usize, ctx: Context) !void {
    try self.writeValueType(writer, val, ctx);

    try self.formatBrackets(writer, "[");

    for (0..len) |i| {
        try self.write(writer, val[i], ctx.incDepth().withListParent());

        if (i != len - 1) {
            _ = try writer.write(", ");
        }
    }

    try self.formatBrackets(writer, "]");

    return;
}

fn formatStruct(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: Context) !void {
    // check if we reached maximum depth and if so, give up.
    if (ctx.cur_depth >= self.options.max_depth) {
        std.debug.print("Max depth({d}) reached, skipping dump.\n", .{self.options.max_depth});

        _ = try writer.write("{...}");

        return;
    }

    // extract value's type metadata.
    const type_of = @TypeOf(val);
    const type_info = @typeInfo(type_of);
    const fields = type_info.@"struct".fields;

    // determine the length required for the field names, so to align the output
    var alignment: u32 = 0;
    if (self.options.structs_pretty_print) {
        inline for (fields) |field| {
            if (field.name.len > alignment) {
                alignment = field.name.len + 1;
            }
        }
    }

    // determine end-of-line character
    const eol = if (self.options.structs_pretty_print) "\n" else " ";

    // print them all!
    try self.writeValueType(writer, val, ctx);

    _ = try writer.print("{{{s}", .{eol});

    inline for (fields, 0..) |field, i| {
        const field_value = @field(val, field.name);
        const sep = if (i < fields.len - 1) "," else "";

        try self.indent(writer, ctx.cur_depth + 1, self.options.structs_pretty_print);

        _ = try writer.print("{s}: ", .{field.name});

        _ = try self.write(writer, field_value, ctx.incDepth());

        _ = try writer.print("{s}{s}", .{ sep, eol });
    }

    try self.indent(writer, ctx.cur_depth, self.options.structs_pretty_print);

    _ = try writer.print("}}", .{});

    return;
}

fn formatType(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: Context) !void {
    try self.writeValueType(writer, val, ctx);

    return self.options.palette.types.write(writer, "{s}", @typeName(val));
}

fn formatFunction(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: Context) !void {
    try self.writeValueType(writer, val, ctx.withoutValue());

    return;
}

fn formatEnum(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: Context) !void {
    try self.writeValueType(writer, val, ctx);

    return self.options.palette.enums.write(writer, "{any}", val);
}

fn formatErrorSet(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: Context) !void {
    try self.writeValueType(writer, val, ctx);

    return self.options.palette.errors.write(writer, "{any}", val);
}

fn formatErrorUnion(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: Context) !void {
    if (val) |in_val| {
        return self.write(writer, in_val, ctx);
    } else |err| {
        return self.formatErrorSet(writer, err, ctx);
    }
}

fn formatVoid(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: Context) !void {
    try self.writeValueType(writer, val, ctx);

    return self.options.palette.empties.write(writer, "{any}", val);
}

fn writeValueType(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: Context) !void {
    if (self.options.print_types and !ctx.has_list_parent) {
        const type_name = if (ctx.parent_type) |typ| @typeName(typ) else @typeName(@TypeOf(val));

        const fmt: []const u8 = if (ctx.print_value) "{s} " else "{s}";

        try self.options.palette.valueTypes.write(writer, fmt, type_name);
    }
}

fn indent(self: *const Dumper, writer: *std.Io.Writer, depth: u16, pretty: bool) !void {
    if (depth == 0) {
        return;
    }

    if (self.options.indent_size <= 0) {
        return;
    }

    if (!pretty) {
        return;
    }

    _ = try writer.splatByte(self.options.indent_char, self.options.indent_size * depth);

    return;
}
