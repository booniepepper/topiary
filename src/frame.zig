const std = @import("std");
const Obj = @import("./values.zig").Value.Obj;

pub const Frame = struct {
    cl: *Obj,
    ip: usize,
    bp: usize,

    pub fn create(obj: *Obj, ip: usize, bp: usize) !Frame {
        if (obj.data != .closure and obj.data != .loop and obj.data != .bough) {
            return error.InvalidType;
        }
        return .{
            .cl = obj,
            .ip = ip,
            .bp = bp,
        };
    }

    pub fn instructions(self: *Frame) []const u8 {
        return switch (self.cl.data) {
            .closure => |c| c.data.function.instructions,
            .loop => |l| l.instructions,
            .bough => |b| b.instructions,
            else => unreachable,
        };
    }
};
