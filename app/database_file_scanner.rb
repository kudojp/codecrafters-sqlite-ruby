class DatabaseFileScanner
  HEADER_LENGTH = 100 # bytes
  HEADER_PAGE_SIZE_OFFSET = 16
  HEADER_PAGE_SIZE_LENGTH = 2

  def initialize(database_file_path)
    @file = File.open(database_file_path, "rb")
  end

  # This returns only the page size currently.
  def dbinfo
    @file.seek(HEADER_PAGE_SIZE_OFFSET)
    page_size = @file.read(HEADER_PAGE_SIZE_LENGTH).unpack("n")[0]
    { page_size: page_size }
  end

end
