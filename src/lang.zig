pub const StringType = enum {
    MutableSliceOfBytes,
    ZeroTerminatedStringSlice,
};

pub const String = union(StringType) {
    MutableSliceOfBytes: []u8,
    ZeroTerminatedStringSlice: [:0]const u8,
};
