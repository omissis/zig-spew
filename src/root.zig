pub const Dumper = @import("Dumper.zig");
pub const theme = @import("theme.zig");

// dump is a convenience function to be used only for debugging purposes: do not use it in production,
// as it creates and destroy the whole dumper every time you call it.
pub fn dump(value: anytype) !void {
    return (Dumper{}).print(value);
}
