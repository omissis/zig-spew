const std = @import("std");
const lang = @import("lang.zig");
const theme = @import("theme.zig");

// dump is a convenience function to be used only for debugging purposes: do not use it in production,
// as it creates and destroy the whole dumper every time you call it.
pub fn dump(value: anytype) !void {
    const d = Dumper{};

    return d.print(value);
}

pub const Dumper = struct {
    options: DumpOptions = .{},

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

    pub fn write(self: *const Dumper, writer: *std.Io.Writer, value: anytype, ctx: DumpContext) !void {
        const type_of = @TypeOf(value);
        const type_info = @typeInfo(type_of);

        // std.debug.print("VALUE: {any}\n", .{value});
        // std.debug.print("TYPE OF: {any}\n", .{type_of});
        // std.debug.print("TYPE INFO: {any}\n", .{type_info});

        switch (type_info) {
            .bool => {
                return self.formatBoolean(writer, value);
            },
            .int => {
                if (self.options.bytes_interpretation) {
                    if (type_info.int.signedness == .unsigned and type_info.int.bits == 8) {
                        return self.formatByte(writer, value);
                    }
                }

                return self.formatInt(writer, value);
            },
            .comptime_int => {
                return self.formatInt(writer, value);
            },
            .float, .comptime_float => {
                return self.formatFloat(writer, value);
            },
            .null => {
                return self.formatNull(writer);
            },
            .undefined => {
                return self.formatUndefined(writer);
            },
            .array => {
                return self.formatList(writer, value, ctx);
            },
            .optional => {
                if (value == null) {
                    return self.formatNull(writer);
                }

                return self.write(writer, value.?, ctx.incDepth());
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
                                            return self.formatString(writer, value);
                                        }
                                    },
                                    else => {},
                                }
                            },
                            else => {},
                        }

                        return self.write(writer, value.*, ctx.incDepth());
                    },
                    .slice => {
                        switch (child_type_info) {
                            .int => {
                                if (child_type_info.int.signedness == .unsigned and child_type_info.int.bits == 8) {
                                    if (self.options.string_interpretation) {
                                        return self.formatString(writer, value);
                                    }
                                }
                            },
                            else => {},
                        }

                        return self.formatList(writer, value, ctx);
                    },
                    else => {},
                }
            },
            .@"struct" => {
                return self.formatStruct(writer, value, ctx);
            },
            // TODO: implement all the following types
            //.type
            //.void
            //.noreturn
            //.error_union
            //.error_set
            //.@"enum"
            //.@"union"
            //.@"fn"
            //.@"opaque"
            //.frame
            //.@"anyframe"
            //.vector
            //.enum_literal
            else => {},
        }

        // std.debug.print("Value {any} has unsupported type: {any}\n", .{ value, type_of });
        // std.debug.print("Type Info: {any}\n", .{type_info});

        return;
    }

    fn formatString(self: *const Dumper, writer: *std.Io.Writer, val: anytype) !void {
        return self.options.palette.strings.write(writer, "\"{s}\"", val);
    }

    fn formatByte(self: *const Dumper, writer: *std.Io.Writer, val: anytype) !void {
        return switch (self.options.bytes_representation) {
            theme.BytesRepresentation.hex => try self.options.palette.bytes.write(writer, "0x{x}", val),
            theme.BytesRepresentation.dec => try self.options.palette.bytes.write(writer, "{d}", val),
        };
    }

    fn formatInt(self: *const Dumper, writer: *std.Io.Writer, val: anytype) !void {
        return self.options.palette.numbers.write(writer, "{d}", val);
    }

    fn formatFloat(self: *const Dumper, writer: *std.Io.Writer, val: anytype) !void {
        return self.options.palette.numbers.write(writer, "{d}", val);
    }

    fn formatBoolean(self: *const Dumper, writer: *std.Io.Writer, val: anytype) !void {
        return try self.options.palette.booleans.write(writer, "{s}", if (val) "true" else "false");
    }

    fn formatNull(self: *const Dumper, writer: *std.Io.Writer) !void {
        return try self.options.palette.empties.write(writer, "{s}", "null");
    }

    fn formatUndefined(self: *const Dumper, writer: *std.Io.Writer) !void {
        return try self.options.palette.empties.write(writer, "{s}", "undefined");
    }

    fn formatBrackets(self: *const Dumper, writer: *std.Io.Writer, val: anytype) !void {
        return try self.options.palette.brackets.write(writer, "{s}", val);
    }

    fn formatList(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: DumpContext) !void {
        try self.formatBrackets(writer, "[");

        for (val, 0..) |item, i| {
            try self.write(writer, item, ctx.incDepth());

            if (i != val.len - 1) {
                _ = try writer.write(", ");
            }
        }

        try self.formatBrackets(writer, "]");

        return;
    }

    fn formatStruct(self: *const Dumper, writer: *std.Io.Writer, val: anytype, ctx: DumpContext) !void {
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
        _ = try writer.print("{s} {{{s}", .{ @typeName(type_of), eol });

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

        _ = try writer.splatByte(self.options.indent_ch, self.options.indent_size * depth);

        return;
    }
};

pub const DumpOptions = struct {
    indent_size: u32 = 4,
    indent_ch: u8 = ' ',
    max_depth: u32 = 10,
    palette: theme.Palette = theme.DefaultPalette,
    decimal_places: u6 = 3,
    decimal_min_width: u6 = 0,
    hex_padding: u6 = 0,
    string_interpretation: bool = true, // whether to interpret arrays and slices of u8 as strings
    bytes_interpretation: bool = true, // whether to interpret u8 as bytes instead of decimals
    bytes_representation: theme.BytesRepresentation = .hex, // wheter to represent bytes as decimals or hexadecimals
    structs_pretty_print: bool = true, // whether to print structs with newlines and indentation or not
};

const DumpContext = struct {
    cur_depth: u16 = 0,

    pub fn incDepth(self: DumpContext) DumpContext {
        var new = self;

        new.cur_depth += 1;

        return new;
    }
};
