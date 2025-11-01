const std = @import("std");
const theme = @import("theme.zig");

pub const Dumper = struct {
    allocator: std.mem.Allocator,
    theme_renderer: theme.Renderer,
    options: DumpOptions,

    pub fn init(allocator: std.mem.Allocator, options: DumpOptions) Dumper {
        return .{
            .allocator = allocator,
            .theme_renderer = theme.Renderer.init(allocator, options.rendering),
            .options = options,
        };
    }

    pub fn print(self: *Dumper, value: anytype, ctx: theme.RenderContext) !void {
        const out = try self.dump(value, ctx);

        try std.fs.File.stdout().writeAll(out);
        try std.fs.File.stdout().writeAll("\n");
    }

    // TODO: implement deinit?

    pub fn dump(self: *Dumper, value: anytype, ctx: theme.RenderContext) ![]const u8 {
        const opts = if (ctx.options == null) self.options.rendering else ctx.options.?;
        const child_ctx = ctx.incDepth();
        const type_of = @TypeOf(value);
        const type_info = @typeInfo(type_of);

        // std.debug.print("VALUE: {any}\n", .{value});
        // std.debug.print("TYPE OF: {any}\n", .{type_of});
        // std.debug.print("TYPE INFO: {any}\n", .{type_info});

        switch (type_info) {
            .bool => {
                return try self.theme_renderer.formatBoolean(value, child_ctx);
            },
            .int => {
                if (opts.bytes_interpretation) {
                    if (type_info.int.signedness == .unsigned and type_info.int.bits == 8) {
                        return try self.theme_renderer.formatByte(value, child_ctx);
                    }
                }

                return try self.theme_renderer.formatInt(value, child_ctx);
            },
            .comptime_int => {
                return try self.theme_renderer.formatInt(value, child_ctx);
            },
            .float, .comptime_float => {
                return try self.theme_renderer.formatFloat(value, child_ctx);
            },
            .null => {
                return try self.theme_renderer.formatNull(child_ctx);
            },
            .undefined => {
                return try self.theme_renderer.formatUndefined(child_ctx);
            },
            .array => {
                var w = std.Io.Writer.Allocating.init(self.allocator);

                _ = try w.writer.write("[");

                for (value, 0..) |item, i| {
                    _ = try w.writer.write(try self.dump(item, child_ctx));

                    if (i != value.len - 1) {
                        _ = try w.writer.write(", ");
                    }
                }

                _ = try w.writer.write("]");

                return try w.toOwnedSlice();
            },
            .optional => {
                if (value == null) {
                    return try self.theme_renderer.formatNull(child_ctx);
                }

                return try self.dump(value.?, child_ctx);
            },
            // TODO
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
                                            return try self.theme_renderer.formatString(value, child_ctx);
                                        }

                                        return try self.dump(value.*, child_ctx);
                                    },
                                    else => {
                                        std.debug.print("TODO");
                                    },
                                }
                            },
                            else => {
                                std.debug.print("TODO");
                            },
                        }
                    },
                    else => {
                        std.debug.print("TODO");
                    },
                }

                if (type_info.pointer.size == .slice and child_type_info.int.signedness == .unsigned and child_type_info.int.bits == 8) {
                    return try self.string(type_of, value, child_ctx);
                }

                return "";
            },
            // .@"struct" => {
            //     return try self.@"struct"(type_of, value, ctx);
            // },
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
            else => {
                std.debug.print("Unsupported type: {}\n", .{@typeInfo(type_of)});
                return DumpError.UnsupportedType;
            },
        }

        return try self.buffer.toOwnedSlice();
    }

    fn @"struct"(self: *Dumper, comptime T: type, value: T, ctx: theme.RenderContext) ![]const u8 {
        if (ctx.cur_depth >= self.options.max_depth) {
            std.debug.print("Max depth({d}) reached, skipping dump.\n", .{self.options.max_depth});

            return "";
        }

        const type_of = @TypeOf(value);
        const type_info = @typeInfo(type_of);
        const fields = type_info.@"struct".fields;

        // determine the length required for the field names, so to align the output
        comptime var alignment: u32 = 0;

        inline for (fields) |field| {
            if (field.name.len > alignment) {
                alignment = field.name.len + 1;
            }
        }

        try self.appendf("{s}{s} {{\n", .{ try self.indent(ctx), @typeName(type_of) });

        const field_format = std.fmt.comptimePrint("{{s}}{{s:<{d}}}: {{s}}\n", .{alignment});
        const field_indent = try self.indent(ctx.incDepth());
        defer self.allocator.free(field_indent);

        inline for (fields) |field| {
            const field_value = @field(value, field.name);
            const field_type_name = @typeName(field.type);

            if (std.mem.indexOf(u8, field_type_name, "ArrayList") != null) {
                const v = try self.arrayList(field.type, field_value, ctx.incDepth());
                defer self.allocator.free(v);

                try self.appendf(field_format, .{ field_indent, field.name, v });
            } else if (std.mem.indexOf(u8, field_type_name, "ArrayHashMap") != null) {
                const v = try self.arrayHashMap(field.type, field_value, ctx.incDepth());
                defer self.allocator.free(v);

                try self.appendf(field_format, .{ field_indent, field.name, v });
            } else {
                switch (field.type) {
                    []u8, []const u8 => {
                        const v = try self.string(field.type, field_value, ctx);
                        defer self.allocator.free(v);

                        try self.appendf(field_format, .{ field_indent, field.name, v });
                    },
                    else => {
                        const v = "unsupported";

                        try self.appendf(field_format, .{ field_indent, field.name, v });
                    },
                }
            }
        }

        try self.appendf("{s}}}\n", .{try self.indent(ctx)});

        return self.buffer.toOwnedSlice();
    }

    fn string(self: *Dumper, comptime T: type, value: T, _: theme.RenderContext) ![]const u8 {
        return try self.sprintf("\"{s}\"", .{value});
    }

    fn arrayList(self: *Dumper, comptime T: type, _: T, _: theme.RenderContext) ![]const u8 {
        return try self.sprintf("{s}", .{"ARRAY_LIST"}); // TODO: print value
    }

    fn arrayHashMap(self: *Dumper, comptime T: type, value: T, ctx: theme.RenderContext) ![]const u8 {
        var str = std.ArrayList(u8).init(self.allocator);
        defer str.deinit();

        try str.writer().print("[\n", .{});

        const info = @typeInfo(T);
        if (info != .@"struct") return error.UnsupportedType;

        var it = value.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            const val = try self.dump(@TypeOf(entry.value_ptr.*), entry.value_ptr.*, ctx.incDepth());

            try str.writer().print("{s}{s}: {s}\n", .{ try self.indent(ctx.incDepth()), key, val });
        }

        // var it = value.iterator();

        // while (it.next()) |entry| {
        //     std.debug.print("key: {s}, value: {s}\n", .{ entry.key, entry.value });
        // }

        try str.writer().print("{s}]\n", .{try self.indent(ctx)});

        return str.toOwnedSlice();
    }

    fn indent(self: *Dumper, ctx: theme.RenderContext) ![]u8 {
        if (ctx.cur_depth == 0) {
            return &.{};
        }

        if (self.options.indent_size <= 0) {
            return &.{};
        }

        const buf = try self.allocator.alloc(u8, self.options.indent_size * ctx.cur_depth);

        @memset(buf, self.options.indent_str[0]);

        return buf;
    }

    fn sprintf(self: *Dumper, comptime fmt: []const u8, args: anytype) ![]u8 {
        return try std.fmt.allocPrint(self.allocator, fmt, args);
    }

    fn appendf(self: *Dumper, comptime fmt: []const u8, args: anytype) !void {
        try self.buffer.writer().print(fmt, args);
    }
};

pub const DumpError = error{
    UnsupportedType,
};

pub const DumpOptions = struct {
    indent_size: u32 = 4,
    indent_str: []const u8 = " ",
    max_depth: u32 = 10,
    rendering: theme.RenderOptions = .{},
};
