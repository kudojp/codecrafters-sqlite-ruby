Dir["./app/database/*.rb"].each {|file| require file }
Dir["./app/database_file_scanner/*.rb"].each {|file| require file }

class DatabaseFileScanner
  HEADER_LENGTH = 100 # bytes
  PAGE_SIZE_OFFSET_IN_FILE_HEADER = 16
  PAGE_SIZE_LENGTH_IN_FILE_HEADER = 2
  SQLITE_SCHEMA_PAGE_NUMBER = 1

  def initialize(database_file_path)
    @file = File.open(database_file_path, "rb")
  end

  def header_info
    @header_info = Database::HeaderInfo.new(page_size: page_size)
  end

  def sqlite_schema
    @sqlite_schema ||= get_sqlite_schema
  end

  def count_records(table_name)
    table_info = self.sqlite_schema.tables.find{|tbl| tbl.fetch(:name) == table_name}
    table_root_page_index = table_info.fetch(:rootpage)

    TableBTreeTraverser.new(@file, self.page_size, table_root_page_index).cnt_records
  end

  private

  def page_size
    @page_size ||= get_page_size
  end

  def get_page_size
    @file.seek(PAGE_SIZE_OFFSET_IN_FILE_HEADER)
    @file.read(PAGE_SIZE_LENGTH_IN_FILE_HEADER).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)
  end

  def get_sqlite_schema
    sqlite_schema = Database::SqliteSchema.new

    sqlite_schema.cnt_tables = TableBTreeTraverser.new(@file, page_size, SQLITE_SCHEMA_PAGE_NUMBER, Database::SqliteSchema::TABLE_ATTRIBUTES).cnt_records
    sqlite_schema.tables = TableBTreeTraverser.new(@file, page_size, SQLITE_SCHEMA_PAGE_NUMBER, Database::SqliteSchema::TABLE_ATTRIBUTES).get_records
    sqlite_schema
  end
end
