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
end
