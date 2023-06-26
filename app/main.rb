require './app/database_file_scanner.rb'
require './app/plan_and_executor'
Dir["./app/database/*.rb"].each {|file| require file }
require './simplest_sql_parser/lib/simplest_sql_parser'

database_file_path = ARGV[0]
command = ARGV[1]

db_file_scanner = DatabaseFileScanner.new(database_file_path)

case command
when ".dbinfo"
  header_info = db_file_scanner.header_info
  puts "database page size: #{header_info.page_size}"

  sqlite_schema = db_file_scanner.sqlite_schema
  puts "number of tables: #{sqlite_schema.tables.length}"
when ".tables"
  sqlite_schema = db_file_scanner.sqlite_schema
  puts sqlite_schema.tables.map{|tbl| tbl.fetch("name")}.join " "
else
  ast = SimplestSqlParser.parse(command)
  result = PlanAndExecutor.new(ast, db_file_scanner).execute
  puts result
end
