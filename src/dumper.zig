const std = @import("std");
const lang = @import("lang.zig");
const theme = @import("theme.zig");

pub const Dumper = struct {
    allocator: std.mem.Allocator,
    options: DumpOptions,

    pub fn init(allocator: std.mem.Allocator, options: DumpOptions) Dumper {
        return .{
            .allocator = allocator,
            .options = options,
        };
    }

    pub fn print(self: *Dumper, value: anytype, ctx: DumpContext) !void {
        const out = try self.dump(value, ctx);

        try std.fs.File.stdout().writeAll(out);
        try std.fs.File.stdout().writeAll("\n");
    }

    pub fn dump(self: *Dumper, value: anytype, ctx: DumpContext) ![]const u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        const type_of = @TypeOf(value);
        const type_info = @typeInfo(type_of);

        // std.debug.print("VALUE: {any}\n", .{value});
        // std.debug.print("TYPE OF: {any}\n", .{type_of});
        // std.debug.print("TYPE INFO: {any}\n", .{type_info});

        switch (type_info) {
            .bool => {
                return try self.formatBoolean(value, ctx);
            },
            .int => {
                if (opts.bytes_interpretation) {
                    if (type_info.int.signedness == .unsigned and type_info.int.bits == 8) {
                        return try self.formatByte(value, ctx);
                    }
                }

                return try self.formatInt(value, ctx);
            },
            .comptime_int => {
                return try self.formatInt(value, ctx);
            },
            .float, .comptime_float => {
                return try self.formatFloat(value, ctx);
            },
            .null => {
                return try self.formatNull(ctx);
            },
            .undefined => {
                return try self.formatUndefined(ctx);
            },
            .array => {
                return try self.formatList(value, ctx);
            },
            .optional => {
                if (value == null) {
                    return try self.formatNull(ctx);
                }

                return try self.dump(value.?, ctx.incDepth());
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
                                        if (opts.string_interpretation) {
                                            return try self.formatString(value, ctx);
                                        }
                                    },
                                    else => {},
                                }
                            },
                            else => {},
                        }

                        return try self.dump(value.*, ctx.incDepth());
                    },
                    .slice => {
                        switch (child_type_info) {
                            .int => {
                                if (child_type_info.int.signedness == .unsigned and child_type_info.int.bits == 8) {
                                    if (opts.string_interpretation) {
                                        return try self.formatString(value, ctx);
                                    }
                                }
                            },
                            else => {},
                        }

                        return try self.formatList(value, ctx);
                    },
                    else => {},
                }
            },
            .@"struct" => {
                return try self.formatStruct(value, ctx);
            },
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

        std.debug.print("Value {any} has unsupported type: {any}\n", .{ value, type_of });
        std.debug.print("Type Info: {any}\n", .{type_info});

        return "unsupported";
    }

    fn formatString(self: *Dumper, val: anytype, ctx: DumpContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        // TODO: find if there's a way to tell if a value is known at comptime
        // const str_val = if (@typeInfo(@TypeOf(val)).pointer.is_const) lang.String{
        //     .ZeroTerminatedStringSlice = "\"" ++ val ++ "\"",
        // } else lang.String{
        //     .MutableSliceOfBytes = try std.fmt.allocPrint(self.allocator, "\"{s}\"", .{val}),
        // };
        const str_val = lang.String{
            .MutableSliceOfBytes = try std.fmt.allocPrint(self.allocator, "\"{s}\"", .{val}),
        };

        return try opts.palette.strings.format(self.allocator, str_val);
    }

    fn formatByte(self: *Dumper, val: anytype, ctx: DumpContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        const bytes = switch (opts.bytes_representation) {
            theme.BytesRepresentation.hex => try std.fmt.allocPrint(self.allocator, "0x{x}", .{val}),
            theme.BytesRepresentation.dec => try std.fmt.allocPrint(self.allocator, "{d}", .{val}),
        };
        const str_val = lang.String{ .MutableSliceOfBytes = bytes };

        return try opts.palette.bytes.format(self.allocator, str_val);
    }

    fn formatInt(self: *Dumper, val: anytype, ctx: DumpContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        const str_val = lang.String{
            .MutableSliceOfBytes = try std.fmt.allocPrint(self.allocator, "{d}", .{val}),
        };

        return try opts.palette.numbers.format(self.allocator, str_val);
    }

    fn formatFloat(self: *Dumper, val: anytype, ctx: DumpContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        const str_val = lang.String{
            .MutableSliceOfBytes = try std.fmt.allocPrint(self.allocator, "{d}", .{val}),
        };

        return try opts.palette.numbers.format(self.allocator, str_val);
    }

    fn formatBoolean(self: *Dumper, val: anytype, ctx: DumpContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        const str_val = lang.String{ .ZeroTerminatedStringSlice = if (val) "true" else "false" };

        return try opts.palette.booleans.format(self.allocator, str_val);
    }

    fn formatNull(self: *Dumper, ctx: DumpContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        const str_val = lang.String{ .ZeroTerminatedStringSlice = "null" };

        return try opts.palette.empties.format(self.allocator, str_val);
    }

    fn formatUndefined(self: *Dumper, ctx: DumpContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;
        const str_val = lang.String{ .ZeroTerminatedStringSlice = "undefined" };

        return try opts.palette.empties.format(self.allocator, str_val);
    }

    fn formatBrackets(self: *Dumper, val: anytype, ctx: DumpContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;

        const str_val = lang.String{ .ZeroTerminatedStringSlice = val };

        return try opts.palette.brackets.format(self.allocator, str_val);
    }

    fn formatList(self: *Dumper, val: anytype, ctx: DumpContext) ![]u8 {
        var w = std.Io.Writer.Allocating.init(self.allocator);
        defer w.deinit();

        _ = try w.writer.write(try self.formatBrackets("[", ctx));

        for (val, 0..) |item, i| {
            _ = try w.writer.write(try self.dump(item, ctx.incDepth()));

            if (i != val.len - 1) {
                _ = try w.writer.write(", ");
            }
        }

        _ = try w.writer.write(try self.formatBrackets("]", ctx));

        return try w.toOwnedSlice();
    }

    fn formatStruct(self: *Dumper, val: anytype, ctx: DumpContext) ![]u8 {
        const opts = if (ctx.options == null) self.options else ctx.options.?;

        var w = std.Io.Writer.Allocating.init(self.allocator);
        defer w.deinit();

        if (ctx.cur_depth >= opts.max_depth) {
            std.debug.print("Max depth({d}) reached, skipping dump.\n", .{opts.max_depth});

            _ = try w.writer.write("{...}");

            return w.toOwnedSlice();
        }

        const type_of = @TypeOf(val);
        const type_info = @typeInfo(type_of);
        const fields = type_info.@"struct".fields;

        // determine the length required for the field names, so to align the output
        var alignment: u32 = 0;

        if (opts.structs_pretty_print) {
            inline for (fields) |field| {
                if (field.name.len > alignment) {
                    alignment = field.name.len + 1;
                }
            }
        }

        const eol = if (opts.structs_pretty_print) "\n" else " ";

        _ = try w.writer.print("{s} {{{s}", .{ @typeName(type_of), eol });

        const field_format = "{s}{s}: {s}{s}{s}";
        const field_indent = try self.indent(ctx.cur_depth + 1, opts.structs_pretty_print);
        defer self.allocator.free(field_indent);

        inline for (fields, 0..) |field, i| {
            const field_value = @field(val, field.name);
            const sep = if (i < fields.len - 1) "," else "";

            _ = try w.writer.print(
                field_format,
                .{ field_indent, field.name, try self.dump(field_value, ctx.incDepth()), sep, eol },
            );
        }

        _ = try w.writer.print("{s}}}", .{try self.indent(ctx.cur_depth, opts.structs_pretty_print)});

        return try w.toOwnedSlice();
    }

    fn indent(self: *Dumper, depth: u16, pretty: bool) ![]u8 {
        if (depth == 0) {
            return &.{};
        }

        if (self.options.indent_size <= 0) {
            return &.{};
        }

        if (!pretty) {
            return &.{};
        }

        const size = self.options.indent_size * depth;

        const buf = try self.allocator.alloc(u8, size);

        @memset(buf, self.options.indent_ch);

        return buf;
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
    structs_pretty_print: bool = true,
};

pub const DumpContext = struct {
    cur_depth: u16 = 0,
    options: ?DumpOptions = null,

    pub fn incDepth(self: DumpContext) DumpContext {
        var new = self;

        new.cur_depth += 1;

        return new;
    }
};
