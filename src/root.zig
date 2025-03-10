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

/// multidimensional slice.
/// reinterpret a slice of values as a multidimensional grid with n dimmensions
pub fn MdSlice(n: comptime_int, T: type) type {
    return struct {
        const Self = @This();

        items: [*]T,
        lenghts: [n]usize,

        /// pos <- .{x, y, z...
        pub fn get(self: MdSlice(n, T), pos: [n]usize) T {
            var index: usize = 0;
            var acc: usize = 1;
            for (0..n) |i| {
                std.debug.assert(pos[i] < self.lenghts[i]); // index out of bounds
                index += pos[i] * acc;
                acc *= self.lenghts[i];
            }
            return self.items[index];
        }

        /// pos <- .{x, y, z...
        pub fn set(self: *MdSlice(n, T), pos: [n]usize, item: T) T {
            var index: usize = 0;
            var acc: usize = 1;
            for (0..n) |i| {
                std.debug.assert(pos[i] < self.lenghts[i]); // index out of bounds
                index += pos[i] * acc;
                acc *= self.lenghts[i];
            }
            self.items[index] = item;
        }

        /// buff must be a slice of
        pub fn init(
            buff: anytype,
            range_start: usize,
            lenghts: [n]usize,
        ) Self {
            if (@typeInfo(@TypeOf(buff)) != .Pointer) @compileError("Buff must have a pointer type. Buff is of type " ++ @typeName(@TypeOf(buff)) ++ ".");
            var acc: usize = 1;
            for (0..n) |i| {
                acc *= lenghts[i];
            }
            return Self{
                .items = buff[range_start..acc].ptr,
                .lenghts = lenghts,
            };
        }
    };
}

test MdSlice {
    var buff: [189]i32 = .{69} ** 188 ++ .{88};
    const dslice: MdSlice(1, i32) = .{
        .items = &buff,
        .lenghts = .{8},
    };

    try std.testing.expectEqual(69, dslice.get(.{0}));

    const dslice2 = MdSlice(3, i32).init(&buff, 0, .{ 3, 7, 9 });
    try std.testing.expectEqual(69, dslice2.get(.{ 0, 0, 0 }));
    try std.testing.expectEqual(88, dslice2.get(.{ 2, 6, 8 }));
}

fn levenshteinDistance(T: type, s: []const T, t: []const T, alloc: std.mem.Allocator) !usize {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    var v0 = try arena.allocator().alloc(usize, t.len + 1);
    var v1 = try arena.allocator().alloc(usize, t.len + 1);

    for (v0, 0..) |*value, i| {
        value.* = @intCast(i);
    }

    for (0..s.len) |i| {
        v1[0] = @intCast(i + 1);
        for (0..t.len) |j| {
            const deletion_cost = v0[j + 1] + 1;
            const insertion_cost = v1[j] + 1;
            var substitution_cost: usize = 0;
            if (s[i] == t[j]) {
                substitution_cost = v0[j];
            } else {
                substitution_cost = v0[j] + 1;
            }

            v1[j + 1] = @min(deletion_cost, insertion_cost, substitution_cost);
        }
        std.mem.swap([]usize, &v0, &v1);
    }

    return v0[t.len];
}

test "levenshteinDistance" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(2, try levenshteinDistance(u8, "book", "back", alloc));
    try std.testing.expectEqual(7, try levenshteinDistance(u8, "HAAAA!!", "owo", alloc));
    try std.testing.expectEqual(55, try levenshteinDistance(
        u8,
        "In information theory, linguistics, and computer science, the Levenshtein distance is a string metric for measuring the difference between two sequences.",
        "In train theory, linguistic, and science, the distance Levenshtein is a meter metric for measur the dirence ween wo sequen",
        alloc,
    ));
}
