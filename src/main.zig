const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    const args = try init.minimal.args.toSlice(gpa);
    defer gpa.free(args);

    var filepath: [:0]const u8 = undefined;
    var mode: Mode = undefined;
    for (args) |arg| {
        std.log.info("Arg: {s}", .{arg});
    }

    switch (args.len) {
        2 => {
            filepath = args[1];
            mode = .compile;
        },
        3 => {
            const flag = args[1];
            mode = std.meta.stringToEnum(Mode, flag[2..]) orelse
                return error.UnrecognizedFlag;
            filepath = args[2];
        },
        else => {
            std.debug.print("\nUsage: ./zcc /path/to/source.c\n", .{});
            std.debug.print("--lex - Directs it to run the lexer, but stop before parsing\n", .{});
            std.debug.print("--parse - Directs it to run the lexer and parser, but stop before assembly generation\n", .{});
            std.debug.print("--codegen - Directs it to perform lexing, parsing, and assembly generation, but stop before code emission\n\n", .{});
            std.process.exit(1);
        },
    }

    try checkFileExtension(filepath);

    const preprocessed_filename = try replaceFileExtension(gpa, filepath, "i");
    defer gpa.free(preprocessed_filename);

    var child = try std.process.spawn(
        io,
        .{ .argv = &.{ "gcc", "-E", "-P", filepath, "-o", preprocessed_filename } },
    );
    const term = try child.wait(io);
    if (!std.meta.eql(term, .{ .exited = 0 }))
        return error.PreprocessorFail;

    const file_contents = try std.Io.Dir.cwd().readFileAllocOptions(
        io,
        preprocessed_filename,
        gpa,
        .limited(10 * 1024 * 1024),
        .of(u8),
        0,
    );
    defer gpa.free(file_contents);

    try std.Io.Dir.cwd().deleteFile(io, preprocessed_filename);

    const asm_filename = try replaceFileExtension(gpa, filepath, "s");
    defer gpa.free(asm_filename);

    try compile(mode, file_contents);

    const binary_filename = try removeFileExtension(gpa, filepath);
    defer gpa.free(binary_filename);
}

pub const Mode = enum { lex, parse, codegen, compile, S };

const TokenList = std.MultiArrayList(struct {
    tag: Token.Tag,
    start: u32,
});

fn driver(mode: Mode, source: [:0]const u8) !void {
    switch (mode) {
        .lex => {
            var lexer = Lexer.init(source);
            while (true) {
                const token = lexer.next();
                std.debug.print("{}: {s}\n", .{
                    token.tag,
                    source[token.loc.start..token.loc.end],
                });

                if (token.tag == .invalid) return error.LexerFail;
                if (token.tag == .eof) break;
            }
        },
        .parse => {},
        .codegen => {},
        .S => {},
        .compile => {},
    }
}

fn compile(mode: Mode, file_contents: [:0]const u8) !void {
    try driver(mode, file_contents);
}

fn assemble_and_link(alloc: Allocator, asm_file: []const u8, output_file: []const u8) !void {
    var child = std.process.Child.init(&.{ "gcc", asm_file, "-o", output_file }, alloc);

    defer std.fs.cwd().deleteFile(asm_file) catch {};

    const term = try child.spawnAndWait();
    if (!std.meta.eql(term, .{ .Exited = 0 }))
        return error.AssemblyAndLinkFailed;
}

fn checkFileExtension(file: []const u8) !void {
    const result = std.fs.path.extension(file);
    if (!std.mem.eql(u8, ".c", result)) return error.InvalidExtension;
}

fn removeFileExtension(alloc: Allocator, path: []const u8) ![]const u8 {
    const file = try std.fs.path.join(
        alloc,
        &.{
            std.fs.path.dirname(path) orelse "",
            std.fs.path.stem(path),
        },
    );
    errdefer alloc.free(file);

    return file;
}

fn replaceFileExtension(alloc: Allocator, path: []const u8, extension: []const u8) ![]const u8 {
    const file = try removeFileExtension(alloc, path);
    defer alloc.free(file);

    const replacedExtension = try std.mem.join(
        alloc,
        ".",
        &.{ file, extension },
    );
    errdefer alloc.free(replacedExtension);

    return replacedExtension;
}

// Tests

test "checkFileExtension doesn't throw an error" {
    try checkFileExtension("main.c");
}

test "checkFileExtension throws error" {
    try std.testing.expectError(error.InvalidExtension, checkFileExtension("main.i"));
}

test "replaceFileExtension" {
    const result = try replaceFileExtension(std.testing.allocator, "main.c", "i");
    defer std.testing.allocator.free(result);
    const expected = "main.i";
    try std.testing.expectEqualStrings(expected, result);
}

test "removeFileExtension" {
    const actual = try removeFileExtension(std.testing.allocator, "test/main.c");
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings("test/main", actual);
}
