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
      if (c == ' ' or c == '\t') {
        this.col += 1;
        continue;
      }

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

    var graphemeLen: usize = 0;
    this.peekedGrapheme = try this.nextGrapheme(&graphemeLen);
    // this.col -= 1;
    // this.peeked2Grapheme = try this.peekGrapheme();

    // Check comments
    if (this.peekedGrapheme.? == '/') {
      if (this.peeked2Grapheme.? == '/' or this.peeked2Grapheme.? == '*') return this.getComment();
    }

    // Check identifiers/keywords
    if (validIdentStart(this.peekedGrapheme.?)) {
      this.col -= 1;
      const startCol = this.col;
      const identStartPos = this.pos;

      while (this.pos < this.sourceline.len) {
        // const c = this.sourceline[this.pos];
        const c = try this.nextGrapheme(&graphemeLen);
        if (!validIdentGraph(c)) {
          this.col -= 1;
          break;
        }
        this.pos += graphemeLen;
      }


      const identLexeme = this.sourceline[identStartPos..this.pos];

      // Filter for keywords
      const modKey = "module";
      if (std.mem.eql(u8, identLexeme, modKey)) {
        return Token.init(.KeyModule, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "pub")) {
        return Token.init(.KeyPub, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "fxn")) {
        return Token.init(.KeyFxn, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "if")) {
        return Token.init(.KeyIf, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "else")) {
        return Token.init(.KeyElse, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "return")) {
        return Token.init(.KeyReturn, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "struct")) {
        return Token.init(.KeyStruct, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "enum")) {
        return Token.init(.KeyEnum, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "union")) {
        return Token.init(.KeyUnion, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "while")) {
        return Token.init(.KeyWhile, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "break")) {
        return Token.init(.KeyBreak, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "continue")) {
        return Token.init(.KeyContinue, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "type")) {
        return Token.init(.KeyType, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "const")) {
        return Token.init(.KeyConst, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "let")) {
        return Token.init(.KeyLet, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "var")) {
        return Token.init(.KeyVar, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "mut")) {
        return Token.init(.KeyMut, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "rethrow")) {
        return Token.init(.KeyRethrow, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "catch")) {
        return Token.init(.KeyCatch, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "defer")) {
        return Token.init(.KeyDefer, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "for")) {
        return Token.init(.KeyFor, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "in")) {
        return Token.init(.KeyIn, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "do")) {
        return Token.init(.KeyDo, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "foreach")) {
        return Token.init(.KeyForeach, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "switch")) {
        return Token.init(.KeySwitch, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "nextcase")) {
        return Token.init(.KeyNextcase, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "unwrap")) {
        return Token.init(.KeyUnwrap, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "excuse")) {
        return Token.init(.KeyExcuse, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "yield")) {
        return Token.init(.KeyYield, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "none")) {
        return Token.init(.KeyNone, identLexeme, this.line, startCol);
      } else if (std.mem.eql(u8, identLexeme, "lam") or std.mem.eql(u8, identLexeme, "λ")) {
        return Token.init(.KeyLambda, identLexeme, this.line, startCol);
      }

      return Token.init(.Ident, identLexeme, this.line, startCol);
    }

    // Handle numbers (ints and floats)
    // To make things easier (and the fact that no unicode for numbers), use as character
    var tokType = TokenType.Integer;
    var c = this.sourceline[this.pos];
    var c1 = this.peekCharacter();
    // Numbers can begin with either '.' (for floats), '+', '-', or a digit
    if (validNumberStart(c, c1)) {
      this.col -= 1;
      const startCol = this.col;
      const numberStartPos = this.pos;

      var hasDecimalPoint = false;

      while (this.pos < this.sourceline.len) {
        if (c == '0' and (c1 == 'x' or c1 == 'X')) {
          // Hexadecimal
          this.pos += 2;
          this.col += 2;
          while (this.pos < this.sourceline.len) {
            c = this.sourceline[this.pos];
            if (!std.ascii.isHex(c) and c != '_') break;
            this.pos += 1;
            this.col += 1;
          }
          break;
        } else if (c == '0' and (c1 == 'b' or c1 == 'B')) {
          // Binary
          this.pos += 2;
          this.col += 2;
          while (this.pos < this.sourceline.len) {
            c = this.sourceline[this.pos];
            if (c != '0' and c != '1' and c != '_') break;
            this.pos += 1;
            this.col += 1;
          }
          break;
        } else {
          // Being here means: integer or dot/sign
          if (c == '+' or c == '-') {
            this.pos += 1;
            this.col += 1;
            c = this.sourceline[this.pos];
            c1 = this.peekCharacter();
          } else if (c == 'E' or c == 'e') {
            // Scientific notation
            this.pos += 1;
            this.col += 1;

            c = this.sourceline[this.pos];
            c1 = this.peekCharacter();
            if (c == '+' or c == '-') {
              this.pos += 1;
              this.col += 1;

              if (!std.ascii.isDigit(c1)) {
                return error.UnexpectedCharacter;
              }
            } else if (!std.ascii.isDigit(c)) {
              return error.UnexpectedCharacter;
            }
          } else if (c == '.') {
            if (hasDecimalPoint) {
              // Second decimal point, stop parsing number
              break;
            }
            hasDecimalPoint = true;
            tokType = TokenType.Float;
            this.pos += 1;
            this.col += 1;
          } else if (!std.ascii.isDigit(c) and c != '_') {
            // Not a digit, end of number
            break;
          } else {
            this.pos += 1;
            this.col += 1;
          }
        }
        if (this.pos < this.sourceline.len) {
          c = this.sourceline[this.pos];
          c1 = this.peekCharacter();
        } else {
          break;
        }
      }

      const numberLexeme = this.sourceline[numberStartPos..this.pos];
      return Token.init(tokType, numberLexeme, this.line, startCol);
    }
    


    // Handle string literals
    if (this.peekedGrapheme.? == '"') {
      const startCol = this.col;
      const strStartPos = this.pos;
      this.pos += graphemeLen; // skip opening "
      this.peekedGrapheme = try this.nextGrapheme(&graphemeLen);

      while (this.pos < this.sourceline.len) {
        if (this.peekedGrapheme.? == '"') {
          break;
        }

        // Handle escape sequences
        if (this.peekedGrapheme.? == '\\') {
          this.pos += 1; // skip '\'
          this.col += 1;

          if (this.pos >= this.sourceline.len) return error.UnexpectedCharacter;

          this.pos += 1; // skip escape char
          this.peekedGrapheme = try this.nextGrapheme(&graphemeLen);
        } else {
          this.pos += graphemeLen;
          this.peekedGrapheme = try this.nextGrapheme(&graphemeLen);
        }

        if (this.pos >= this.sourceline.len) return error.UnexpectedCharacter;
      }

      if (this.peekedGrapheme.? != '"') return error.UnexpectedCharacter;

      this.pos += graphemeLen; // skip closing "

      const strLexeme = this.sourceline[strStartPos..this.pos];
      return Token.init(.String, strLexeme, this.line, startCol);
    }

    // Handle characters
    if (this.peekedGrapheme.? == '\'') {
      // A character literal is either an escape '\x' or a single grapheme

      const startCol = this.col;
      const charStartPos = this.pos;
      this.pos += 1; // skip opening '
      this.col += 1;
      if (this.pos >= this.sourceline.len) return error.UnexpectedCharacter;
      this.pos += 1; // skip '\' or grapheme
      this.col += 1;
      if (this.peeked2Grapheme.? == '\\') {
        // Escape sequence
        if (this.pos >= this.sourceline.len) return error.UnexpectedCharacter;
        // For now, only support simple escapes like \n, \t, \', \", \\

        this.pos += 1; // skip escape char
        this.col += 1;

        if (this.pos >= this.sourceline.len) return error.UnexpectedCharacter;
        if (this.peekedGrapheme.? != '\'') return error.UnexpectedCharacter;
      } else {
        // Single grapheme

        if (this.pos >= this.sourceline.len) return error.UnexpectedCharacter;
        if (this.peekedGrapheme.? != '\'') return error.UnexpectedCharacter;
      }
      this.pos += 1; // skip closing '
      this.col += 1;
      const charLexeme = this.sourceline[charStartPos..this.pos];
      return Token.init(.Char, charLexeme, this.line, startCol);
    }


    var len:u32 = 1;
    tokType = TokenType.Unknown;

    // Handle operators and delimiters
    switch (this.peekedGrapheme.?) {
      '=' => {
        if (this.peeked2Grapheme.? == '=') {
          len = 2;
          tokType = .Equal;
        } else if (this.peeked2Grapheme.? == '>') {
          len = 2;
          tokType = .RightArrow;
        } else {
          tokType = .Assign;
        }
      },
      ':' => {
        if (this.peeked2Grapheme.? == '=') {
          len = 2;
          tokType = .LAssign;
        } else if (this.peeked2Grapheme.? == ':') {
          len = 2;
          tokType = .DColon;
        } else {
          tokType = .Colon;
        }
      },
      '?' => {
        if (this.peeked2Grapheme.? == '?') {
          len = 2;
          tokType = .DQuestion;
        } else {
          tokType = .Question;
        }
      },
      '!' => {
        if (this.peeked2Grapheme.? == '!') {
          len = 2;
          tokType = .DExclamation;
        } else {
          tokType = .Exclamation;
        }
      },
      '@' => {
        tokType = .At;
      },
      '_' => {
        tokType = .Underscore;
      },
      '+' => {
        if (this.peeked2Grapheme.? == '+') {
          len = 2;
          tokType = .PlusPlus;
        } else if (this.peeked2Grapheme.? == '=') {
          len = 2;
          tokType = .PlusAssign;
        } else {
          tokType = .Plus;
        }
      },
      '-' => {
        if (this.peeked2Grapheme.? == '-') {
          len = 2;
          tokType = .MinusMinus;
        } else if (this.peeked2Grapheme.? == '=') {
          len = 2;
          tokType = .MinusAssign;
        } else {
          tokType = .Minus;
        }
      },
      '*' => {
        if (this.peeked2Grapheme.? == '=') {
          len = 2;
          tokType = .AsteriskAssign;
        } else {
          tokType = .Asterisk;
        }
      },
      '/' => {
        if (this.peeked2Grapheme.? == '=') {
          len = 2;
          tokType = .DivideAssign;
        } else {
          tokType = .Divide;
        }
      },
      '<' => {
        if (this.peeked2Grapheme.? == '<') {
          const peeked3 = try this.peekGrapheme();

          if (peeked3 == '=') {
            len = 3;
            tokType = .LeftShiftAssign;
          } else {
            len = 2;
            tokType = .LeftShift;
          }
        } else if (this.peeked2Grapheme.? == '=') {
          len = 2;
          tokType = .LessEqual;
        } else {
          // tokType = .LessThan;
          tokType = .LAngle; // Note that '<' can either mean a less-than or a left angle bracket
          // Parser will figure it out
        }
      },
      '>' => {
        if (this.peeked2Grapheme.? == '>') {
          const peeked3 = try this.peekGrapheme();

          if (peeked3 == '=') {
            len = 3;
            tokType = .RightShiftAssign;
          } else {
            len = 2;
            tokType = .RightShift;
          }
        } else if (this.peeked2Grapheme.? == '=') {
          len = 2;
          tokType = .GreaterEqual;
        } else {
          // tokType = .GreaterThan;
          tokType = .RAngle; // Same as '<'
        }
      },
      '&' => {
        if (this.peeked2Grapheme.? == '=') {
          len = 2;
          tokType = .BitAndAssign;
        } else if (this.peeked2Grapheme.? == '&') {
          len = 2;
          tokType = .LogicalAnd;
        } else {
          tokType = .BitAnd;
        }
      },
      '|' => {
        if (this.peeked2Grapheme.? == '=') {
          len = 2;
          tokType = .BitOrAssign;
        } else if (this.peeked2Grapheme.? == '|') {
          len = 2;
          tokType = .LogicalOr;
        } else {
          tokType = .Bar; // Note that `|` can mean a bit or in the context of (a|b) or a capture group as in `|a|`
          // For now, it will be bar until the parser can figure it out
        }
      },
      '^' => {
        if (this.peeked2Grapheme.? == '=') {
          len = 2;
          tokType = .BitXorAssign;
        } else {
          tokType = .BitXor;
        }
      },
      '%' => {
        if (this.peeked2Grapheme.? == '=') {
          len = 2;
          tokType = .ModuloAssign;
        } else {
          tokType = .Modulo;
        }
      },
      '~' => {
        if (this.peeked2Grapheme.? == '=') {
          len = 2;
          tokType = .BitNotAssign;
        } else {
          tokType = .BitNot;
        }
      },
      ',' => {
        tokType = .Comma;
      },
      ';' => {
        tokType = .Semicolon;
      },
      '.' => {
        if (this.peeked2Grapheme.? == '.') {
          len = 2;
          tokType = .DotDot;
        } else {
          tokType = .Dot;
        }
      },
      '(' => {
        tokType = .LParen;
      },
      ')' => {
        tokType = .RParen;
      },
      '{' => {
        tokType = .LBrace;
      },
      '}' => {
        tokType = .RBrace;
      },
      '[' => {
        if (this.peeked2Grapheme.? == '[') {
          len = 2;
          tokType = .AttrStart;
        } else {
          tokType = .LBracket;
        }
      },
      ']' => {
        if (this.peeked2Grapheme.? == ']') {
          len = 2;
          tokType = .AttrEnd;
        } else {
          tokType = .RBracket;
        }
      },
      else => {},
    }

    const lexeme = this.sourceline[this.pos..this.pos + len];
    this.pos += len;

    return Token.init(tokType, lexeme, this.line, this.col - 1);
  }

  /// Advances to the next grapheme and returns it.
  /// Output parameter `outGraphemeLen` is set to the length in bytes of the grapheme.
  /// This is generally 1 byte for ASCII characters but can be up to 4 bytes for Unicode.
  /// For now, λ is the only non-ASCII grapheme supported.
  fn nextGrapheme(this: *Lexer, outGraphemeLen: *usize) !u21 {
    const graphemeLen = try Unicode.utf8ByteSequenceLength(this.sourceline[this.pos]);
    const grapheme = try Unicode.utf8Decode(this.sourceline[this.pos..][0..graphemeLen]);

    outGraphemeLen.* = graphemeLen;
    this.col += 1;

    this.pos += graphemeLen;
    this.peeked2Grapheme = try this.peekGrapheme();
    this.pos -= graphemeLen;

    return grapheme;
  }

  ///
  /// Peeks at the next grapheme without advancing the position.
  ///
  fn peekGrapheme(this: *Lexer) !u21 {
    if (this.pos >= this.sourceline.len) {
      return 0;
    }

    const graphemeLen = try Unicode.utf8ByteSequenceLength(this.sourceline[this.pos]);
    const grapheme = try Unicode.utf8Decode(this.sourceline[this.pos..][0..graphemeLen]);

    return grapheme;
  }

  fn peekCharacter(this: *Lexer) u8 {
    if (this.pos + 1 >= this.sourceline.len) {
      return 0;
    }

    return this.sourceline[this.pos + 1];
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


inline fn validIdentStart(c: u21) bool {
  const isAsciiAlpha = (c >= @as(u21, 'A') and c <= @as(u21, 'Z')) or (c >= @as(u21, 'a') and c <= @as(u21, 'z'));
  return isAsciiAlpha or (c == @as(u21, '_')) or (c == 'λ');
}

inline fn validIdentGraph(c: u21) bool {
  const isAsciiAlnum = (c >= @as(u21, 'A') and c <= @as(u21, 'Z')) or (c >= @as(u21, 'a') and c <= @as(u21, 'z')) or (c >= @as(u21, '0') and c <= @as(u21, '9'));
  return isAsciiAlnum or (c == @as(u21, '_')) or (c == 'λ');
}

inline fn validNumberStart(c:u8, c1:u8) bool {
  return (c == '.' and std.ascii.isDigit(c1)) or (c == '+' and std.ascii.isDigit(c1)) or (c == '-' and std.ascii.isDigit(c1)) or std.ascii.isDigit(c);
}


test "ValidIdentStart" {
  try std.testing.expect(validIdentStart('a'));
  try std.testing.expect(validIdentStart('Z'));
  try std.testing.expect(validIdentStart('_'));
  try std.testing.expect(!validIdentStart('1'));
  try std.testing.expect(!validIdentStart('-'));
}

test "ValidIdentChar" {
  try std.testing.expect(validIdentGraph('a'));
  try std.testing.expect(validIdentGraph('Z'));
  try std.testing.expect(validIdentGraph('_'));
  try std.testing.expect(validIdentGraph('1'));
  try std.testing.expect(!validIdentGraph('-'));
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