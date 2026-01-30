// zig fmt: off

const std = @import("std");

pub const TokenType = enum {
  // Types
  Ident,
  Integer, // 123
  Float, // 3.14
  String, // "..."
  Char, // 'a'

  // Operators
  Assign, // =
  LAssign, // :=
  Question, // ?
  DQuestion, // ??
  Exclamation, // !
  DExclamation, // !!
  RightArrow, // =>
  At, // @
  Underscore, // _
  Plus, // +
  PlusPlus, // ++
  PlusAssign, // +=
  Minus, // -
  MinusMinus, // --
  MinusAssign, // -=
  Asterisk, // * (for multiplication and slice typing)
  AsteriskAssign, // *=
  Divide, // /
  DivideAssign, // /=
  LeftShift, // <<
  LeftShiftAssign, // <<=
  RightShift, // >>
  RightShiftAssign, // >>=
  BitAnd, // &
  BitAndAssign, // &=
  BitOr, // |
  BitOrAssign, // |=
  BitXor, // ^
  BitXorAssign, // ^=
  Modulo, // %
  ModuloAssign, // %=
  BitNot, // ~
  BitNotAssign, // ~=
  LogicalAnd, // &&
  LogicalOr, // ||
  Equal, // ==
  NotEqual, // !=
  LessThan, // <
  LessEqual, // <=
  GreaterThan, // >
  GreaterEqual, // >=

  // Delimiters
  SingleComment, // // ...
  MultiComment, // /* ... */
  Bar, // |
  Comma, // ,
  Colon, // :
  DColon, // ::
  Semicolon, // ;
  Dot, // .
  DotDot, // ..
  LBracket, // [
  RBracket, // ]
  LParen, // (
  RParen, // )
  LBrace, // {
  RBrace, // }
  LAngle, // <
  RAngle, // >

  AttrStart, // [[
  AttrEnd,   // ]]


  // Keywords
  KeyModule,
  KeyPub,
  KeyFxn,
  KeyIf,
  KeyElse,
  KeyReturn,
  KeyStruct,
  KeyEnum,
  KeyUnion,
  KeyWhile,
  KeyBreak,
  KeyContinue,
  KeyType,
  KeyConst,
  KeyLet,
  KeyVar,
  KeyMut,
  KeyRethrow,
  KeyCatch,
  KeyDefer,
  KeyFor,
  KeyIn,
  KeyDo,
  KeyForeach,
  KeySwitch,
  KeyNextcase,
  KeyUnwrap,
  KeyExcuse,
  KeyYield,
  KeyNone,
  KeyLambda, // either 'lam' or 'λ'


  Comment,
  Unknown,
  Eof,
};

pub const Token = struct {
  tokType: TokenType,
  lexeme: []const u8,
  line: usize,
  col: usize,

  pub fn init(tokType: TokenType, lexeme: []const u8, line: usize, col: usize) Token {
    return Token{
      .tokType = tokType,
      .lexeme = lexeme,
      .line = line,
      .col = col,
    };
  }

  pub fn toString(this: Token, allocator: std.mem.Allocator) ![]const u8 {
    // Make a string that is in the form of:
    // Token{tokType = [type], lexeme = "[lexeme]", line = [line], col = [col]}

    const fmt = "Token[tokType = {s}, lexeme = \"{s}\", line = {d}, col = {d}]";
    const tokTypeStr = try std.fmt.allocPrint(allocator, "{s}", .{@tagName(this.tokType)});
    defer allocator.free(tokTypeStr);
    const result = try std.fmt.allocPrint(allocator, fmt, .{ tokTypeStr, this.lexeme, this.line, this.col });
    return result;
  }
};