const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_allocator.deinit();
    const gpa = debug_allocator.allocator();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    var filepath: [:0]const u8 = undefined;
    var mode: Mode = undefined;

    switch (args.len) {
        2 => {
            filepath = args[1];
            mode = .compile;
        },
        3 => {
            filepath = args[1];
            const flag = args[2];
            mode = std.meta.stringToEnum(Mode, flag[2..]) orelse
                return error.UnrecognizedFlag;
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

    // produce the preprocessed file
    const preprocessed_filename = try replaceFileExtension(gpa, filepath, "i");
    defer gpa.free(preprocessed_filename);

    var child = std.process.Child.init(
        &.{ "gcc", "-E", "-P", filepath, "-o", preprocessed_filename },
        gpa,
    );
    const term = try child.spawnAndWait();
    if (!std.meta.eql(term, .{ .Exited = 0 }))
        return error.PreprocessorFail;


    const file_contents = try std.fs.cwd().readFileAlloc(gpa, preprocessed_filename, 10 * 1024 * 1024);
    defer gpa.free(file_contents);

    try std.fs.cwd().deleteFile(preprocessed_filename);

    const asm_filename = try replaceFileExtension(gpa, filepath, "s");
    defer gpa.free(asm_filename);

    compile(file_contents);

    const binary_filename = try removeFileExtension(gpa, filepath);
    defer gpa.free(binary_filename);

    driver(mode);
}

pub const Mode = enum { lex, parse, codegen, compile, S };

fn driver(mode: Mode) void {
    switch (mode) {
        .lex => {},
        .parse => {},
        .codegen => {},
        .S => {},
        .compile => {},
    }
}

fn compile(file_contents: []u8) void {
    _ = file_contents;
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
