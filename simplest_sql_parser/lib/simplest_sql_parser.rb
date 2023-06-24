# frozen_string_literal: true

require_relative "simplest_sql_parser/version"
require_relative "simplest_sql_parser/lexical_scanner.rex"
require_relative "simplest_sql_parser/parser.tab"

module SimplestSqlParser
  class << self
    def parse(query)
      Parser.new(query).do_parse
    end
  end
end
