const std = @import("std");
const values = @import("./values.zig");
const Gc = @import("./gc.zig").Gc;
const OpCode = @import("./opcode.zig").OpCode;

const Value = values.Value;
pub const Builtin = *const fn (gc: *Gc, args: []Value) Value;

pub const Rnd = struct {
    const Self = @This();
    var r: ?std.rand.DefaultPrng = null;
    var value: Value = .{
        .obj = &Self.obj,
    };
    var obj: Value.Obj = .{
        .data = .{
            .builtin = .{
                .backing = Self.builtin,
                .arity = 2,
            },
        },
    };
    fn builtin(_: *Gc, args: []Value) Value {
        if (r == null) r = std.rand.DefaultPrng.init(std.crypto.random.int(u64));
        const start = @as(i32, @intFromFloat(args[0].number));
        const end = @as(i32, @intFromFloat(args[1].number));
        return .{ .number = @as(f32, @floatFromInt(r.?.random().intRangeAtMost(i32, start, end))) };
    }
};

const Rnd01 = struct {
    const Self = @This();
    var r: ?std.rand.DefaultPrng = null;
    var value: Value = .{
        .obj = &Self.obj,
    };
    var obj: Value.Obj = .{
        .data = .{
            .builtin = .{
                .backing = Self.builtin,
                .arity = 0,
            },
        },
    };
    fn builtin(_: *Gc, args: []Value) Value {
        if (r == null) r = std.rand.DefaultPrng.init(std.crypto.random.int(u64));
        _ = args;
        return .{ .number = r.?.random().float(f32) };
    }
};

const Print = struct {
    const Self = @This();
    var value: Value = .{
        .obj = &Self.obj,
    };
    var obj: Value.Obj = .{
        .data = .{
            .builtin = .{ .backing = Self.builtin, .arity = 1 },
        },
    };
    fn builtin(_: *Gc, args: []Value) Value {
        args[0].print(std.debug, null);
        std.debug.print("\n", .{});
        return values.Nil;
    }
};

const Definition = struct {
    name: []const u8,
    value: *Value,
};

pub const builtins = [_]Definition{ .{
    .name = "rnd",
    .value = &Rnd.value,
}, .{
    .name = "rnd01",
    .value = &Rnd01.value,
}, .{
    .name = "print",
    .value = &Print.value,
} };

pub const Count = struct {
    const Self = @This();
    pub var value: Value = .{
        .obj = &Self.obj,
    };
    var obj: Value.Obj = .{
        .data = .{
            .builtin = .{ .backing = Self.builtin, .arity = 1 },
        },
    };
    fn builtin(_: *Gc, args: []Value) Value {
        var data = args[0].obj.data;
        var count = switch (data) {
            .list => |l| l.items.len,
            .map => |m| m.count(),
            .set => |s| s.count(),
            else => 0,
        };
        return .{ .number = @as(f32, @floatFromInt(count)) };
    }
};

pub const Add = struct {
    const Self = @This();
    pub var value: Value = .{
        .obj = &Self.obj,
    };
    var obj: Value.Obj = .{
        .data = .{
            .builtin = .{ .backing = Self.builtin, .arity = 2 },
        },
    };
    fn builtin(_: *Gc, args: []Value) Value {
        var item = args[1];
        switch (args[0].obj.data) {
            .list => args[0].obj.data.list.append(item) catch {},
            .set => args[0].obj.data.set.put(item, {}) catch {},
            else => unreachable,
        }
        return values.Nil;
    }
};

pub const AddMap = struct {
    const Self = @This();
    pub var value: Value = .{
        .obj = &Self.obj,
    };
    var obj: Value.Obj = .{
        .data = .{
            .builtin = .{ .backing = Self.builtin, .arity = 3 },
        },
    };
    fn builtin(_: *Gc, args: []Value) Value {
        var key = args[1];
        var item = args[2];
        switch (args[0].obj.data) {
            .map => args[0].obj.data.map.put(key, item) catch {},
            else => unreachable,
        }
        return values.Nil;
    }
};
pub const Remove = struct {
    const Self = @This();
    pub var value: Value = .{
        .obj = &Self.obj,
    };
    var obj: Value.Obj = .{
        .data = .{
            .builtin = .{ .backing = Self.builtin, .arity = 2 },
        },
    };
    fn builtin(_: *Gc, args: []Value) Value {
        var item = args[1];
        switch (args[0].obj.data) {
            .list => {
                for (args[0].obj.data.list.items, 0..) |it, i| {
                    if (!Value.eql(it, item)) continue;
                    _ = args[0].obj.data.list.orderedRemove(i);
                    break;
                }
            },
            .set => _ = args[0].obj.data.set.orderedRemove(item),
            .map => _ = args[0].obj.data.map.orderedRemove(item),
            else => unreachable,
        }
        return values.Nil;
    }
};

pub const Has = struct {
    const Self = @This();
    pub var value: Value = .{
        .obj = &Self.obj,
    };
    var obj: Value.Obj = .{
        .data = .{
            .builtin = .{ .backing = Self.builtin, .arity = 2 },
        },
    };
    fn builtin(_: *Gc, args: []Value) Value {
        var item = args[1];
        const result = switch (args[0].obj.data) {
            .list => blk: {
                for (args[0].obj.data.list.items) |it| {
                    if (!Value.eql(it, item)) continue;
                    break :blk true;
                }
                break :blk false;
            },
            .set => args[0].obj.data.set.contains(item),
            .map => args[0].obj.data.map.contains(item),
            .string => |s| blk: {
                if (item.obj.data != .string) break :blk false;
                const len = item.obj.data.string.len;
                for (0..s.len) |i| {
                    if (i + len > s.len) break;
                    if (std.mem.eql(u8, s[i..(i + len)], item.obj.data.string)) break :blk true;
                }
                break :blk false;
            },
            else => false,
        };
        if (result) return values.True;
        return values.False;
    }
};
pub const Clear = struct {
    const Self = @This();
    pub var value: Value = .{
        .obj = &Self.obj,
    };
    var obj: Value.Obj = .{
        .data = .{
            .builtin = .{ .backing = Self.builtin, .arity = 1 },
        },
    };
    fn builtin(_: *Gc, args: []Value) Value {
        var data = args[0].obj.data;
        switch (data) {
            .list => data.list.clearAndFree(),
            .map => data.map.clearAndFree(),
            .set => data.set.clearAndFree(),
            else => {},
        }
        return values.Nil;
    }
};
