require './app/database_file_scanner.rb'
Dir["./app/database/*.rb"].each {|file| require file }

database_file_path = ARGV[0]
command = ARGV[1]

scanner = DatabaseFileScanner.new(database_file_path)

case command
when ".dbinfo"
  header_info = scanner.get_header_info
  puts "database page size: #{header_info.page_size}"

  sqlite_schema = scanner.get_sqlite_schema
  puts "number of tables: #{sqlite_schema.cnt_tables}"
when ".tables"
  sqlite_schema = scanner.get_sqlite_schema
  puts sqlite_schema.tables.map{|tbl| tbl.fetch(:name)}.join " "
else
  # Assuming that th command is "SELECT COUNT(*) FROM my_table;"
  table_name = command.split(" ")[3]
  tables = scanner.get_sqlite_schema.tables
  table = tables.find{|tbl| tbl.fetch(:name) == table_name}
  root_page_index = table.fetch(:rootpage)

  header_info = scanner.get_header_info
  puts DatabaseFileScanner::TableBTreeTraverser.new(
    File.open(database_file_path, "rb"),
    header_info.page_size,
    root_page_index,
    nil
  ).cnt_records
end
