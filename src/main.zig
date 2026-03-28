const std = @import("std");

pub fn main() !void {}

pub const Mode = enum { lex, parse, codegen, compile, assembly };

const Args = struct {
    path: [:0]const u8,
    mode: Mode,
};

fn parseArgs(alloc: std.mem.Allocator) !Args {
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const mode: Mode = undefined;
    const path: [:0]const u8 = undefined;

    switch (args.len) {
        1 => return error.PathNotFound,
        2 => {
            path = args[1];
            mode = .compile;
        },
        3 => {
            path = args[1];
            mode = std.meta.stringToEnum(Mode, args[2]) orelse return error.UnrecognizedFlag;
        },
        else => unreachable,
    }

    return .{ .path = path, .mode = mode };
}
