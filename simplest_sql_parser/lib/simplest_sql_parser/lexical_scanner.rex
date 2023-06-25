# ref. https://github.com/tenderlove/rexical/blob/master/DOCUMENTATION.ja.rdoc

class SimplestSqlParser::LexicalScanner
option
  ignorecase
macro
  BLANK \s+
  NUMBER \d+(\.\d+)?
  WORD [a-zA-Z]\w*
  LITERAL '.+'

rule
  # Each line should be formatted as:
  # `start_state pattern { action }
  #
  # - In action should return [:TOKEN_SYMBOL, value] (ref. https://docs.ruby-lang.org/en/3.2/Racc/Parser.html#method-i-next_token)

  {BLANK}   # do nothing

  # keywords
  ## keyword of statements
  SELECT\b { [:SELECT, text] }
  FROM\b { [:FROM, text] }
  WHERE\b { [:WHERE, text] }

  ## keyword of functions
  COUNT\b { [:COUNT, text] }

  # tokens
  ,   { [:COMMA, text] }
  \*   { [:ASTERISK, text] }
  =   {[:EQUALS, text]}
  \(   {[:PARENTHESIS_LEFT, text]}
  \)   {[:PARENTHESIS_RIGHT, text]}

  # identifiers
  {LITERAL} { [:IDENTIFIER, text[1...-1]] }
  {NUMBER} {[:IDENTIFIER, text.to_f]}
  {WORD} { [:IDENTIFIER, text] }
