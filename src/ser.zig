const getty = @import("getty");
const std = @import("std");

pub const ser = struct {
    pub usingnamespace @import("ser/interface.zig");
    pub usingnamespace @import("ser/impl.zig");

    pub usingnamespace @import("ser/escape.zig");
    pub usingnamespace @import("ser/serializer.zig");
};

/// Serialize the given value as JSON into the given I/O stream.
pub fn toWriter(writer: anytype, value: anytype) !void {
    var f = ser.CompactFormatter(@TypeOf(writer)){};
    var s = ser.Serializer(@TypeOf(writer), @TypeOf(f.formatter())).init(writer, f.formatter());

    try getty.serialize(s.serializer(), value);
}

/// Serialize the given value as pretty-printed JSON into the given I/O stream.
pub fn toPrettyWriter(writer: anytype, value: anytype) !void {
    var f = ser.PrettyFormatter(@TypeOf(writer)).init();
    var s = ser.Serializer(@TypeOf(writer), @TypeOf(f.formatter())).init(writer, f.formatter());

    try getty.serialize(s.serializer(), value);
}

/// Serialize the given value as JSON into the given I/O stream with the given
/// visitor.
pub fn toWriterWith(writer: anytype, value: anytype, visitor: anytype) !void {
    var f = ser.CompactFormatter(@TypeOf(writer)){};
    var s = ser.Serializer(@TypeOf(writer), @TypeOf(f.formatter())).init(writer, f.formatter());

    try getty.serializeWith(s.serializer(), visitor, value);
}

/// Serialize the given value as pretty-printed JSON into the given I/O stream
/// with the given visitor.
pub fn toPrettyWriterWith(writer: anytype, value: anytype, visitor: anytype) !void {
    var f = ser.PrettyFormatter(@TypeOf(writer)).init();
    var s = ser.Serializer(@TypeOf(writer), @TypeOf(f.formatter())).init(writer, f.formatter());

    try getty.serializeWith(s.serializer(), visitor, value);
}

/// Serialize the given value as a JSON string.
///
/// The serialized string is an owned slice. The caller is responsible for
/// freeing the returned memory.
pub fn toString(allocator: *std.mem.Allocator, value: anytype) ![]const u8 {
    var array_list = std.ArrayList(u8).init(allocator);
    errdefer array_list.deinit();

    try toWriter(array_list.writer(), value);
    return array_list.toOwnedSlice();
}

/// Serialize the given value as a pretty-printed JSON string.
///
/// The serialized string is an owned slice. The caller is responsible for
/// freeing the returned memory.
pub fn toPrettyString(allocator: *std.mem.Allocator, value: anytype) ![]const u8 {
    var array_list = std.ArrayList(u8).init(allocator);
    errdefer array_list.deinit();

    try toPrettyWriter(array_list.writer(), value);
    return array_list.toOwnedSlice();
}

/// Serialize the given value as a JSON string with the given visitor.
///
/// The serialized string is an owned slice. The caller is responsible for
/// freeing the returned memory.
pub fn toStringWith(allocator: *std.mem.Allocator, value: anytype, visitor: anytype) ![]const u8 {
    var array_list = std.ArrayList(u8).init(allocator);
    errdefer array_list.deinit();

    try toWriterWith(array_list.writer(), value, visitor);
    return array_list.toOwnedSlice();
}

/// Serialize the given value as a pretty-printed JSON string with the given
/// visitor.
///
/// The serialized string is an owned slice. The caller is responsible for
/// freeing the returned memory.
pub fn toPrettyStringWith(allocator: *std.mem.Allocator, value: anytype, visitor: anytype) ![]const u8 {
    var array_list = std.ArrayList(u8).init(allocator);
    errdefer array_list.deinit();

    try toPrettyWriterWith(array_list.writer(), value, visitor);
    return array_list.toOwnedSlice();
}

test "toWriter - Array" {
    try t(.compact, [_]i8{}, "[]");
    try t(.compact, [_]i8{1}, "[1]");
    try t(.compact, [_]i8{ 1, 2, 3, 4 }, "[1,2,3,4]");

    const T = struct { x: i32 };
    try t(.compact, [_]T{ T{ .x = 10 }, T{ .x = 100 }, T{ .x = 1000 } }, "[{\"x\":10},{\"x\":100},{\"x\":1000}]");
}

test "toWriter - ArrayList" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    try t(.compact, list, "[1,2,3]");
}

test "toWriter - Bool" {
    try t(.compact, true, "true");
    try t(.compact, false, "false");
}

test "toWriter - Enum" {
    try t(.compact, enum { foo }.foo, "\"foo\"");
    try t(.compact, .foo, "\"foo\"");
}

test "toWriter - Error" {
    try t(.compact, error.Foobar, "\"Foobar\"");
}

test "toWriter - HashMap" {
    var map = std.StringHashMap(i32).init(std.testing.allocator);
    defer map.deinit();

    try map.put("x", 1);
    try map.put("y", 2);

    try t(.compact, map, "{\"x\":1,\"y\":2}");
}

test "toWriter - Integer" {
    try t(.compact, 'A', "65");
    try t(.compact, std.math.maxInt(u32), "4294967295");
    try t(.compact, std.math.maxInt(u64), "18446744073709551615");
    try t(.compact, std.math.minInt(i32), "-2147483648");
    try t(.compact, std.math.maxInt(i64), "9223372036854775807");
}

test "toWriter - Float" {
    try t(.compact, 0.0, "0.0e+00");
    try t(.compact, 1.0, "1.0e+00");
    try t(.compact, -1.0, "-1.0e+00");

    try t(.compact, @as(f32, 42.0), "4.2e+01");
    try t(.compact, @as(f64, 42.0), "4.2e+01");
}

test "toWriter - Null" {
    try t(.compact, null, "null");

    try t(.compact, @as(?u8, null), "null");
    try t(.compact, @as(?*u8, null), "null");
}

test "toWriter - String" {
    try t(.compact, "foobar", "\"foobar\"");
    try t(.compact, "with\nescapes\r", "\"with\\nescapes\\r\"");
    try t(.compact, "with unicode\u{1}", "\"with unicode\\u0001\"");
    try t(.compact, "with unicode\u{80}", "\"with unicode\u{80}\"");
    try t(.compact, "with unicode\u{FF}", "\"with unicode\u{FF}\"");
    try t(.compact, "with unicode\u{100}", "\"with unicode\u{100}\"");
    try t(.compact, "with unicode\u{800}", "\"with unicode\u{800}\"");
    try t(.compact, "with unicode\u{8000}", "\"with unicode\u{8000}\"");
    try t(.compact, "with unicode\u{D799}", "\"with unicode\u{D799}\"");
    try t(.compact, "with unicode\u{10000}", "\"with unicode\u{10000}\"");
    try t(.compact, "with unicode\u{10FFFF}", "\"with unicode\u{10FFFF}\"");
    try t(.compact, "/", "\"/\"");
}

test "toWriter - Struct" {
    try t(.compact, struct {}{}, "{}");
    try t(.compact, struct { x: void }{ .x = {} }, "{}");
    try t(
        .compact,
        struct { x: i32, y: i32, z: struct { x: bool, y: [3]i8 } }{
            .x = 1,
            .y = 2,
            .z = .{ .x = true, .y = .{ 1, 2, 3 } },
        },
        "{\"x\":1,\"y\":2,\"z\":{\"x\":true,\"y\":[1,2,3]}}",
    );
}

test "toWriter - Tuple" {
    try t(.compact, .{ 1, true, "ring" }, "[1,true,\"ring\"]");
}

test "toWriter - Tagged Union" {
    try t(.compact, union(enum) { Foo: i32, Bar: bool }{ .Foo = 42 }, "42");
}

test "toWriter - Vector" {
    try t(.compact, @splat(2, @as(u32, 1)), "[1,1]");
}

test "toWriter - Void" {
    try t(.compact, {}, "null");
}

test "toPrettyWriter - Struct" {
    try t(.pretty, struct {}{}, "{}");
    try t(.pretty, struct { x: i32, y: i32, z: struct { x: bool, y: [3]i8 } }{
        .x = 1,
        .y = 2,
        .z = .{ .x = true, .y = .{ 1, 2, 3 } },
    },
        \\{
        \\  "x": 1,
        \\  "y": 2,
        \\  "z": {
        \\    "x": true,
        \\    "y": [
        \\      1,
        \\      2,
        \\      3
        \\    ]
        \\  }
        \\}
    );
}

const Format = enum { compact, pretty };

fn t(format: Format, value: anytype, expected: []const u8) !void {
    const ValidationWriter = struct {
        remaining: []const u8,

        const Self = @This();

        pub const Error = error{
            TooMuchData,
            DifferentData,
        };

        fn init(s: []const u8) Self {
            return .{ .remaining = s };
        }

        /// Implements `std.io.Writer`.
        pub fn writer(self: *Self) std.io.Writer(*Self, Error, write) {
            return .{ .context = self };
        }

        fn write(self: *Self, bytes: []const u8) Error!usize {
            if (self.remaining.len < bytes.len) {
                std.debug.warn("\n" ++
                    \\======= expected: =======
                    \\{s}
                    \\======== found: =========
                    \\{s}
                    \\=========================
                , .{
                    self.remaining,
                    bytes,
                });
                return error.TooMuchData;
            }

            if (!std.mem.eql(u8, self.remaining[0..bytes.len], bytes)) {
                std.debug.warn("\n" ++
                    \\======= expected: =======
                    \\{s}
                    \\======== found: =========
                    \\{s}
                    \\=========================
                , .{
                    self.remaining[0..bytes.len],
                    bytes,
                });
                return error.DifferentData;
            }

            self.remaining = self.remaining[bytes.len..];

            return bytes.len;
        }
    };

    var w = ValidationWriter.init(expected);

    try switch (format) {
        .compact => toWriter(w.writer(), value),
        .pretty => toPrettyWriter(w.writer(), value),
    };

    if (w.remaining.len > 0) {
        return error.NotEnoughData;
    }
}