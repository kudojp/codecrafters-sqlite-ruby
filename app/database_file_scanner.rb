Dir["./app/database/*.rb"].each {|file| require file }
Dir["./app/database_file_scanner/*.rb"].each {|file| require file }

class DatabaseFileScanner
  HEADER_LENGTH = 100 # bytes
  PAGE_SIZE_OFFSET_IN_FILE_HEADER = 16
  PAGE_SIZE_LENGTH_IN_FILE_HEADER = 2
  SQLITE_SCHEMA_PAGE_NUMBER = 0

  def initialize(database_file_path)
    @file = File.open(database_file_path, "rb")
  end

  def get_header_info
    Database::HeaderInfo.new(page_size: page_size)
  end

  def get_sqlite_schema
    # TODO: implement like maybe as follows.
    sqlite_schema = Database::SqliteSchema.new

    sqlite_schema.cnt_tables = TableBTreeTraverser.new(@file, page_size, SQLITE_SCHEMA_PAGE_NUMBER).cnt_records
    sqlite_schema
  end

  private

  def page_size
    @page_size ||= get_page_size
  end

  def get_page_size
    @file.seek(PAGE_SIZE_OFFSET_IN_FILE_HEADER)
    @file.read(PAGE_SIZE_LENGTH_IN_FILE_HEADER).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)
  end
end
