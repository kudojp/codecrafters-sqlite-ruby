require './app/database_file_scanner.rb'
Dir["./app/database/*.rb"].each {|file| require file }

database_file_path = ARGV[0]
command = ARGV[1]

scanner = DatabaseFileScanner.new(database_file_path)

case command
when ".dbinfo"
  header_info = scanner.header_info
  puts "database page size: #{header_info.page_size}"

  sqlite_schema = scanner.sqlite_schema
  puts "number of tables: #{sqlite_schema.cnt_tables}"
when ".tables"
  sqlite_schema = scanner.sqlite_schema
  puts sqlite_schema.tables.map{|tbl| tbl.fetch(:name)}.join " "
else
  # Assuming that the command is "SELECT xxx FROM yyy;"
  matches = /(?i)select(?-i) (?<columns>.+) +(?i)from(?-i) +(?<table_name>\S+)/.match command
  columns = matches[:columns]
  table_name = matches[:table_name]

  if columns == "count(*)"
    puts scanner.count_records(table_name)
    return
  end

  records = scanner.get_records(table_name)

  # columns = `col, col2, col3`
  column_names = columns.split(",").map(&:strip)
  select_cols = lambda{|record| column_names.map{|col| record.fetch(col)}.join "|"}
  puts records.map{|record| select_cols.call(record)}.join "\n"
end
