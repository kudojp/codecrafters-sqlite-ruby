class DatabaseFileScanner
  HEADER_LENGTH = 100 # bytes
  PAGE_SIZE_OFFSET_IN_FILE_HEADER = 16
  PAGE_SIZE_LENGTH_IN_FILE_HEADER = 2
  BTREE_PAGE_TYPE_OFFSET_IN_PAGE = 0
  BTREE_PAGE_TYPE_LENGTH_IN_PAGE = 1
  NUM_CELLS_OFFSET_IN_PAGE = 3
  NUM_CELLS_LENGTH_IN_PAGE = 2
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

    sqlite_schema.cnt_tables = self.cnt_records_in_b_tree(SQLITE_SCHEMA_PAGE_NUMBER)
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

  # Page at page_index is supposed to be the root node.
  def cnt_records_in_b_tree(page_index)
    first_offset = page_size * page_index
    first_offset += HEADER_LENGTH if page_index == 0 

    page_typ_offset = first_offset + BTREE_PAGE_TYPE_OFFSET_IN_PAGE
    @file.seek(self.file_offset_from_page_offset(page_index, page_typ_offset))
    page_type = @file.read(BTREE_PAGE_TYPE_LENGTH_IN_PAGE).unpack("C")[0] # C: unsigned char (8-bit) in network byte order (= big-endian)

    case page_type
    when *[0x02, 0x0a] # an interior/left index b-tree page
      # TODO: call read_index_btree()
    when *[0x05, 0x0d] # an interior/leaf table b-tree page
      self.cnt_records_in_table_b_tree(page_index)
    else
      raise StandardError.new("unknown page type: #{page_type}")
    end
  end

  def cnt_records_in_table_b_tree(page_index)
    first_offset = page_size * page_index
    first_offset += HEADER_LENGTH if page_index == 0 

    page_typ_offset = first_offset + BTREE_PAGE_TYPE_OFFSET_IN_PAGE
    @file.seek(file_offset_from_page_offset(page_index, page_typ_offset))
    page_type = @file.read(BTREE_PAGE_TYPE_LENGTH_IN_PAGE).unpack("C")[0] # C: unsigned char (8-bit) in network byte order (= big-endian)

    if page_type == 0x0d # a leaf table b-tree page
      @file.seek(file_offset_from_page_offset(page_index, first_offset + NUM_CELLS_OFFSET_IN_PAGE))
      num_cells = @file.read(NUM_CELLS_LENGTH_IN_PAGE).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)      
      return num_cells
    end

    # TODO
    # got down the b-tree recursively.
  end

  def file_offset_from_page_offset(page_index, page_offset)
    page_size * page_index + page_offset
  end
end
