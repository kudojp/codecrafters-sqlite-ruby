# ref. https://github.com/tenderlove/rexical/blob/master/DOCUMENTATION.ja.rdoc

class SimplestSqlParser::LexicalScanner
option
  ignorecase
macro
  BLANK \s+
  WORD [a-zA-Z]\w*
  NUMBER \d+(\.\d+)?

rule
  # Each line should be formatted as:
  # `start_state pattern { action }
  #
  # - In action should return [:TOKEN_SYMBOL, value] (ref. https://docs.ruby-lang.org/en/3.2/Racc/Parser.html#method-i-next_token)

  {BLANK}   # do nothing

  # keywords
  ## keyword of statements
  SELECT { [:SELECT, text] }
  FROM { [:FROM, text] }
  WHERE { [:WHERE, text] }

  ## keyword of functions
  COUNT { [:COUNT, text] }

  # tokens
  ,   { [:COMMA, text] }
  \*   { [:ASTERISK, text] }
  =   {[:EQUALS, text]}
  \(   {[:PARENTHESIS_LEFT, text]}
  \)   {[:PARENTHESIS_RIGHT, text]}

  # identifiers
  {WORD} { [:IDENTIFIER, text] }
  {NUMBER} {[:IDENTIFIER, text.to_f]}
