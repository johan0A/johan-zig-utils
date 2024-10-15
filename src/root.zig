const std = @import("std");
const builtin = @import("builtin");

/// casts floats and ints to T
/// casting float to an int converts the integer part of the floating point number (aka rounds torwards zero)
pub fn cast(T: type, x: anytype) T {
    switch (@typeInfo(@TypeOf(x))) {
        .Float => switch (@typeInfo(T)) {
            .Float => return @floatCast(x),
            .Int => return @intFromFloat(x),
            else => @compileError("casting from " ++ @typeName(@TypeOf(x)) ++ " to " ++ @typeName(T) ++ " is unsuported"),
        },
        .Int => switch (@typeInfo(T)) {
            .Float => return @floatFromInt(x),
            .Int => return @intCast(x),
            else => @compileError("casting from " ++ @typeName(@TypeOf(x)) ++ " to " ++ @typeName(T) ++ " is unsuported"),
        },
        else => {
            @compileError("casting from " ++ @typeName(@TypeOf(x)) ++ " is unsuported");
        },
    }
}

test "cast" {
    try std.testing.expectEqual(@as(i32, 10), cast(i32, @as(u32, 10)));
    try std.testing.expectEqual(@as(f32, 10), cast(f32, @as(u32, 10)));
    try std.testing.expectEqual(@as(i32, 10), cast(i32, @as(f32, 10.6)));
    try std.testing.expectEqual(@as(u32, 10), cast(u32, @as(i32, 10)));
    try std.testing.expectEqual(@as(u32, 10), cast(u32, @as(i32, 10)));
}

/// This function invokes undefined behavior when ok is false. In Debug and ReleaseSafe modes, calls to this function are always generated, and the unreachable statement triggers a panic. In ReleaseFast and ReleaseSmall modes, calls to this function are optimized away, and in fact the optimizer is able to use the assertion in its heuristics. Inside a test block, it is best to use the std.testing module rather than this function, because this function may not detect a test failure in ReleaseFast and ReleaseSmall mode. Outside of a test block, this assert function is the correct function to use.
pub fn assertPrint(ok: bool, comptime fmt: []const u8, args: anytype) void {
    if (!ok) {
        std.log.err(fmt, args);
        unreachable;
    }
}

inline fn isTypeProbablyStringType(comptime T: type) bool {
    if (T == []const u8) return true;
    if (T == [:0]const u8) return true;
    switch (@typeInfo(T)) {
        .Pointer => |ptr_info| {
            switch (@typeInfo(ptr_info.child)) {
                .Array => |array_info| {
                    return ptr_info.is_const and
                        array_info.child == u8 and
                        array_info.sentinel != null and
                        std.meta.sentinel(ptr_info.child) == 0;
                },
                else => return false,
            }
        },
        else => return false,
    }
}

/// Print to stderr, unbuffered, and silently returning on failure. Intended for use in "printf debugging." Use std.log functions for proper logging
/// args are displayed one after the other separated by ", "
/// args of type `@typeOf("")`, `[]const u8` and `[:0]const u8` are formated as `strings` other types are formated as `"any"`
/// adds a return line at the end of the printed string
pub fn ezPrint(args: anytype) void {
    comptime var fmt: []const u8 = &.{};
    inline for (std.meta.fields(@TypeOf(args))) |field| {
        if (isTypeProbablyStringType(field.type)) {
            fmt = fmt ++ "{s}, ";
        } else {
            fmt = fmt ++ "{any}, ";
        }
    }
    fmt = fmt[0 .. fmt.len - 2];
    fmt = fmt ++ "\n";
    std.debug.print(fmt, args);
}
