// zig fmt: off

const std = @import("std");
const Unicode = std.unicode;

// const Token = @import("ast").token.Token;
// const TokenType = @import("ast").token.TokenType;
const Token = @import("../ast/token.zig").Token;
const TokenType = @import("../ast/token.zig").TokenType;


const LexerError = error{
  UnexpectedCharacter,
  UnterminatedComment,
};


pub const Lexer = struct {
  allocator: std.mem.Allocator,

  sourceline: []const u8,
  pos: usize,
  line: usize,
  col: usize,

  peekedGrapheme: ?u21,
  peekedToken: ?Token,

  peeked2Grapheme: ?u21,
  peeked2Token: ?Token,

  pub fn init(allocator: std.mem.Allocator, sourceline: []const u8) Lexer {
    return Lexer{
      .allocator = allocator,
      .sourceline = sourceline,
      .pos = 0,
      .line = 1,
      .col = 1,
      .peekedGrapheme = null,
      .peekedToken = null,
      .peeked2Grapheme = null,
      .peeked2Token = null,
    };
  }

  pub fn nextToken(this: *Lexer) !Token {
    // Skip the space
    while (true) : (this.pos += 1) {
      // Normally isWhitespace could be used but it takes in the newline
      // That needs to be handled separately for line/col tracking
      if (this.pos >= this.sourceline.len) break;

      const c = this.sourceline[this.pos];
      if (c == ' ' or c == '\t') continue;

      if (this.sourceline[this.pos] == '\n') {
        this.line += 1;
        this.col = 1;
        // Also take into consideration carriage return
        if (c == '\r') this.pos += 1;
      } else {
        break;
      }
    }

    // Check if EOF
    if (this.pos >= this.sourceline.len) return Token.init(.Eof, "", this.line, this.col);

    this.peekedGrapheme = try this.nextGrapheme();
    this.peeked2Grapheme = try this.peekGrapheme();

    // Check comments
    if (this.peekedGrapheme.? == '/') {
      if (this.peeked2Grapheme.? == '/' or this.peeked2Grapheme.? == '*') return this.getComment();
    }

    return Token.init(.Unknown, "", this.line, this.col);
  }

  fn nextGrapheme(this: *Lexer) !u21 {
    const graphemeLen = try Unicode.utf8ByteSequenceLength(this.sourceline[this.pos]);
    const grapheme = try Unicode.utf8Decode(this.sourceline[this.pos..][0..graphemeLen]);

    this.pos += graphemeLen;

    return grapheme;
  }

  ///
  /// Peeks at the next grapheme without advancing the position.
  ///
  fn peekGrapheme(this: *Lexer) !u21 {
    const graphemeLen = try Unicode.utf8ByteSequenceLength(this.sourceline[this.pos]);
    const grapheme = try Unicode.utf8Decode(this.sourceline[this.pos..][0..graphemeLen]);

    return grapheme;
  }

  fn getComment(this: *Lexer) !Token {
    if (this.peekedGrapheme.? == '/' and this.peeked2Grapheme.? == '/') {
      const startCol = this.col;
      const commentStartPos = this.pos - 1; // include first '/'

      // Advance until end of line or EOF
      while (this.pos < this.sourceline.len) {
        const c = this.sourceline[this.pos];
        if (c == '\n' or c == 0) break;
        this.pos += 1;
        this.col += 1;
      }
      const commentLexeme = this.sourceline[commentStartPos..this.pos];

      this.peekedGrapheme = this.sourceline[this.pos];
      this.peeked2Grapheme = if (this.pos + 1 < this.sourceline.len) this.sourceline[this.pos + 1] else null;

      return Token.init(.Comment, commentLexeme, this.line, startCol);
    } else if (this.peekedGrapheme.? == '/' and this.peeked2Grapheme.? == '*') {
      // Multi-line comment
      const startCol = this.col;
      const commentStartPos = this.pos - 1; // include first '/'
      this.pos += 1; // skip '*'
      this.col += 1;

      while (this.pos < this.sourceline.len - 1) {
        const c = this.sourceline[this.pos];
        const nextC = this.sourceline[this.pos + 1];
        if (c == '*' and nextC == '/') {
          this.pos += 2; // skip '*/'
          this.col += 2;
          const commentLexeme = this.sourceline[commentStartPos..this.pos];
          this.pos += 1;

          return Token.init(.Comment, commentLexeme, this.line, startCol);
        }
        if (c == '\n') {
          this.line += 1;
          this.col = 1;
        } else {
          this.col += 1;
        }
        this.pos += 1;
      }

      return error.UnterminatedComment;
    }

    return error.UnexpectedCharacter;
  }

};


inline fn validIdentStart(c: u8) bool {
  return (std.ascii.isAlphabetic(c)) or (c == '_');
}

inline fn validIdentChar(c: u8) bool {
  return std.ascii.isAlphanumeric(c) or (c == '_');
}


test "ValidIdentStart" {
  try std.testing.expect(validIdentStart('a'));
  try std.testing.expect(validIdentStart('Z'));
  try std.testing.expect(validIdentStart('_'));
  try std.testing.expect(!validIdentStart('1'));
  try std.testing.expect(!validIdentStart('-'));
}

test "ValidIdentChar" {
  try std.testing.expect(validIdentChar('a'));
  try std.testing.expect(validIdentChar('Z'));
  try std.testing.expect(validIdentChar('_'));
  try std.testing.expect(validIdentChar('1'));
  try std.testing.expect(!validIdentChar('-'));
}

test "NextGrapheme" {
  const allocator = std.testing.allocator;

  const source = "map(arr, λ(a,b)=>a*b);";
  var lexer = Lexer.init(allocator, source);

  const expectedGraphemes = [_][]const u8{
    "m", "a", "p", "(", "a", "r", "r", ",", " ", 
    "λ", "(", "a", ",", "b", ")", "=", ">", "a", "*", "b", ")", ";",
  };

  for (expectedGraphemes) |expected| {
    const grapheme = try lexer.nextGrapheme();
    try std.testing.expectEqualSlices(u8, expected, grapheme);
  }
}

test "SkipComments" {
  const allocator = std.testing.allocator;

  const source = "// This is a comment\n   var x = 10; /* multi-line \n comment */ var y = 20;";
  var lexer = Lexer.init(allocator, source);

  lexer.skipComments();
  try std.testing.expect(lexer.pos == 25); // position after single-line comment

  lexer.skipComments();
  try std.testing.expect(lexer.pos == source.len); // position after multi-line comment
}