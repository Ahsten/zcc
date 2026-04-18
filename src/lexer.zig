const Token = @import("token.zig").Token;
const std = @import("std");

pub const Lexer = struct {
    buffer: [:0]const u8,
    index: usize,

    pub fn init(buffer: [:0]const u8) Lexer {
        return .{
            .buffer = buffer,
            .index = 0,
        };
    }

    const State = enum {
        start,
        invalid,
        identifier,
        int,
    };

    pub fn next(self: *Lexer) Token {
        var token: Token = .{
            .tag = undefined,
            .loc = .{
                .start = self.index,
                .end = undefined,
            },
        };

        state: switch (State.start) {
            .start => switch (self.buffer[self.index]) {
                0 => {
                    if (self.index == self.buffer.len) {
                        return .{
                            .tag = .eof,
                            .loc = .{
                                .start = self.index,
                                .end = self.index,
                            },
                        };
                    } else {
                        continue :state .invalid;
                    }
                },
                ' ', '\n', '\t', '\r' => {
                    self.index += 1;
                    token.loc.start = self.index;
                    continue :state .start;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    token.tag = .identifier;
                    continue :state .identifier;
                },
                '0'...'9' => {
                    token.tag = .number_literal;
                    continue :state .int;
                },
                '{' => {
                    token.tag = .l_brace;
                    self.index += 1;
                },

                '}' => {
                    token.tag = .r_brace;
                    self.index += 1;
                },

                '(' => {
                    token.tag = .l_paren;
                    self.index += 1;
                },

                ')' => {
                    token.tag = .r_paren;
                    self.index += 1;
                },
                ';' => {
                    token.tag = .semicolon;
                    self.index += 1;
                },
                else => continue :state .invalid,
            },
            .invalid => {
                token.tag = .invalid;
            },
            .identifier => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    'a'...'z', 'A'...'Z', '_' => continue :state .identifier,
                    else => {
                        const ident = self.buffer[token.loc.start..self.index];
                        if (Token.getKeywords(ident)) |tag| {
                            token.tag = tag;
                        }
                    },
                }
            },
            .int => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '0'...'9' => continue :state .int,
                    'a'...'z', 'A'...'Z' => continue :state .invalid,
                    else => {},
                }
            },
        }

        token.loc.end = self.index;
        return token;
    }
};

test "chapter 1 tokens" {
    try testLexer(
        \\int main(void) { return 2; }
    , &.{
        .keyword_int,
        .identifier,
        .l_paren,
        .keyword_void,
        .r_paren,
        .l_brace,
        .keyword_return,
        .number_literal,
        .semicolon,
        .r_brace,
    });
}

fn testLexer(source: [:0]const u8, expected_token_tags: []const Token.Tag) !void {
    var tokenizer = Lexer.init(source);
    for (expected_token_tags) |expected_token_tag| {
        const token = tokenizer.next();
        try std.testing.expectEqual(expected_token_tag, token.tag);
    }
    // Last token should always be eof, even when the last token was invalid,
    // in which case the tokenizer is in an invalid state, which can only be
    // recovered by opinionated means outside the scope of this implementation.
    const last_token = tokenizer.next();
    try std.testing.expectEqual(Token.Tag.eof, last_token.tag);
    try std.testing.expectEqual(source.len, last_token.loc.start);
    try std.testing.expectEqual(source.len, last_token.loc.end);
}
