class DatabaseFileScanner
  HEADER_LENGTH = 100 # bytes
  HEADER_PAGE_SIZE_OFFSET = 16
  HEADER_PAGE_SIZE_LENGTH = 2

  def initialize(database_file_path)
    @file = File.open(database_file_path, "rb")
  end

  def get_header_info
    @file.seek(HEADER_PAGE_SIZE_OFFSET)
    page_size = @file.read(HEADER_PAGE_SIZE_LENGTH).unpack("n")[0]
    Database::HeaderInfo.new(page_size: page_size)
  end

  def get_sqlite_schema
    # TODO: implement like maybe as follows.
    sqlite_schema = Database::SqliteSchema.new
    # sqlite_schema.add_table(some_table)
  end
end
