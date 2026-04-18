const std = @import("std");

pub const Token = struct {
    tag: Tag,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "int", .keyword_int },
        .{ "void", .keyword_void },
        .{ "return", .keyword_return },
    });

    pub fn getKeywords(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }

    pub const Tag = enum {
        l_paren,
        r_paren,
        l_brace,
        r_brace,
        identifier,
        semicolon,
        number_literal,
        keyword_int,
        keyword_void,
        keyword_return,
        invalid,
        eof,

        pub fn lexeme(tag: Tag) ?[]const u8 {
            return switch (tag) {
                .invalid,
                .identifier,
                .number_literal,
                .eof,
                => null,

                .l_paren => "(",
                .r_paren => ")",
                .l_brace => "{",
                .r_brace => "}",
                .semicolon => ";",
                .keyword_int => "int",
                .keyword_void => "void",
                .keyword_return => "return",
            };
        }
    };
};
