# SimplestSqlParser

SimplestSqlParser is a toy SQL parser written in Ruby.
Currently it can parse queries composed only of `SELECT`, `FROM`, and `WHERE` clauses.

- `SELECT name, address, age FROM table WHERE id = 12` (SELECT multiple columns)
- `SELECT * FROM table WHERE id = 12` (SELECT all columns)
- `SELECT COUNT(*) FROM table  WHERE id = 12` (COUNT function)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'simplest_sql_parser'
```

And then execute:

```
$ bundle install
```

Or install it yourself as:

```
$ gem install simplest_sql_parser
```

## Usage

```rb
ast = SimplestSqlParser.parse("Select name FROM table")
# And do something creative with ast!
```

## Development

To update the lex scanner `SimplestSQLParser::LexicalScanner`,
1. Update `lib/simplest_sql_parser/lexical_scanner.rex`
2. Run $`bundle exec rex lib/simplest_sql_parser/lexical_scanner.rex`
3. Test your implementation with `bundle exec rspec spec/lexical_scanner_spec.rb`


To update the parser `SimplestSQLParser::Parser`,
1. Update `lib/simplest_sql_parser/parser.racc`
2. Run $`bundle exec racc lib/simplest_sql_parser/parser.rex`
3. Test your implementation with `bundle exec rspec spec/parser/do_parse_spec.rb`

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kudojp/simplest_sql_parser. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/simplest_sql_parser/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SimplestSqlParser project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/simplest_sql_parser/blob/master/CODE_OF_CONDUCT.md).
