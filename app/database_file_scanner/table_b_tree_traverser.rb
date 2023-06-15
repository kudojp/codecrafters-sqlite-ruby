class DatabaseFileScanner
  class TableBTreeTraverser
    BTREE_PAGE_TYPE_OFFSET_IN_PAGE = 0
    BTREE_PAGE_TYPE_LENGTH_IN_PAGE = 1
    NUM_CELLS_OFFSET_IN_PAGE = 3
    NUM_CELLS_LENGTH_IN_PAGE = 2

    def initialize(file, page_size, root_page_index)
      @file = file
      @page_size = page_size
      @root_page_index = root_page_index
    end

    def cnt_records
      first_offset = @page_size * @root_page_index
      first_offset += HEADER_LENGTH if @root_page_index == 0 

      page_typ_offset = first_offset + BTREE_PAGE_TYPE_OFFSET_IN_PAGE
      @file.seek(self.file_offset_from_page_offset(@root_page_index, page_typ_offset))
      page_type = @file.read(BTREE_PAGE_TYPE_LENGTH_IN_PAGE).unpack("C")[0] # C: unsigned char (8-bit) in network byte order (= big-endian)

      raise StandardError.new("Page type: #{page_type} is not for a node in B-tree table.") unless [0x05, 0x0d].include?(page_type)

      if page_type == 0x0d # a leaf table b-tree page
        @file.seek(file_offset_from_page_offset(@root_page_index, first_offset + NUM_CELLS_OFFSET_IN_PAGE))
        num_cells = @file.read(NUM_CELLS_LENGTH_IN_PAGE).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)      
        return num_cells
      end

      # TODO: go down the b-tree recursively.
    end

    def file_offset_from_page_offset(page_index, page_offset)
      @page_size * page_index + page_offset
    end
  end
end
