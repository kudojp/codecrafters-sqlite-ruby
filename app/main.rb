require './app/database_file_scanner.rb'

database_file_path = ARGV[0]
command = ARGV[1]

scanner = DatabaseFileScanner.new(database_file_path)

if command == ".dbinfo"
  dbinfo = scanner.dbinfo
  puts "database page size: #{dbinfo[:page_size]}"
end
