class DatabaseFileScanner
  HEADER_LENGTH = 100 # bytes
  PAGE_SIZE_OFFSET_IN_HEADER = 16
  PAGE_SIZE_LENGTH_IN_HEADER = 2

  def initialize(database_file_path)
    @file = File.open(database_file_path, "rb")
  end

  def get_header_info
    @file.seek(PAGE_SIZE_OFFSET_IN_HEADER)
    page_size = @file.read(PAGE_SIZE_LENGTH_IN_HEADER).unpack("n")[0]
    Database::HeaderInfo.new(page_size: page_size)
  end

  def get_sqlite_schema
    # TODO: implement like maybe as follows.
    sqlite_schema = Database::SqliteSchema.new
    # sqlite_schema.add_table(some_table)
  end
end
