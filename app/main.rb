require './app/database_file_scanner.rb'
Dir["./app/database/*.rb"].each {|file| require file }

database_file_path = ARGV[0]
command = ARGV[1]

scanner = DatabaseFileScanner.new(database_file_path)

if command == ".dbinfo"
  header_info = scanner.header_info
  puts "database page size: #{header_info.page_size}"
end
