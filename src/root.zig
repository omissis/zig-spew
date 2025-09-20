const std = @import("std");

pub const DumpOptions = struct {
    indent_size: u32 = 4,
    indent_str: []const u8 = " ",
    max_depth: u32 = 10,
};

pub const DumpContext = struct {
    cur_depth: u32 = 0,

    fn incDepth(self: DumpContext) DumpContext {
        return DumpContext{
            .cur_depth = self.cur_depth + 1,
        };
    }
};

pub const Dumper = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8),
    opts: DumpOptions,

    pub fn init(allocator: std.mem.Allocator, opts: DumpOptions) Dumper {
        const buffer = std.ArrayList(u8).init(allocator);

        return .{
            .allocator = allocator,
            .buffer = buffer,
            .opts = opts,
        };
    }

    pub fn deinit(self: *Dumper) void {
        self.buffer.deinit();
    }

    pub fn dump(self: *Dumper, comptime T: type, value: T, ctx: DumpContext) ![]const u8 {
        const type_of = @TypeOf(value);

        switch (@typeInfo(type_of)) {
            .@"struct" => {
                return try self.@"struct"(type_of, value, ctx);
            },
            .int => {
                return try self.int(type_of, value, ctx);
            },
            .array => {
                return try self.string(type_of, value, ctx);
            },
            // TODO: types like Draft2020_12.Property are not supported, we need to do through a different path
            else => {
                std.debug.print("Unsupported type: {s}\n", .{type_of});
                return "not implemented";
            },
        }

        return try self.buffer.toOwnedSlice();
    }

    fn @"struct"(self: *Dumper, comptime T: type, value: T, ctx: DumpContext) ![]const u8 {
        if (ctx.cur_depth >= self.opts.max_depth) {
            std.debug.print("Max depth({d}) reached, skipping dump.\n", .{self.opts.max_depth});

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

    fn string(self: *Dumper, comptime T: type, value: T, _: DumpContext) ![]const u8 {
        return try self.sprintf("\"{s}\"", .{value});
    }

    fn int(self: *Dumper, comptime T: type, value: T, _: DumpContext) ![]const u8 {
        return try self.sprintf("{d}", .{value});
    }

    fn arrayList(self: *Dumper, comptime T: type, _: T, _: DumpContext) ![]const u8 {
        return try self.sprintf("{s}", .{"ARRAY_LIST"}); // TODO: print value
    }

    fn arrayHashMap(self: *Dumper, comptime T: type, value: T, ctx: DumpContext) ![]const u8 {
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

    fn indent(self: *Dumper, ctx: DumpContext) ![]u8 {
        if (ctx.cur_depth == 0) {
            return &.{};
        }

        if (self.opts.indent_size <= 0) {
            return &.{};
        }

        const buf = try self.allocator.alloc(u8, self.opts.indent_size * ctx.cur_depth);

        @memset(buf, self.opts.indent_str[0]);

        return buf;
    }

    fn sprintf(self: *Dumper, comptime fmt: []const u8, args: anytype) ![]u8 {
        return try std.fmt.allocPrint(self.allocator, fmt, args);
    }

    fn appendf(self: *Dumper, comptime fmt: []const u8, args: anytype) !void {
        try self.buffer.writer().print(fmt, args);
    }
};
