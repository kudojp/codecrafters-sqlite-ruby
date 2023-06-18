class DatabaseFileScanner
  class TableBTreeTraverser
    BTREE_PAGE_TYPE_OFFSET_IN_PAGE = 0
    BTREE_PAGE_TYPE_LENGTH_IN_PAGE = 1
    NUM_CELLS_OFFSET_IN_PAGE = 3
    NUM_CELLS_LENGTH_IN_PAGE = 2

    def initialize(file, page_size, root_page_index, columns)
      @file = file
      @page_size = page_size
      @root_page_index = root_page_index
      @columns = columns
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

    # Returns an array structured like:
    # [
    #   {type: "type1", name: "name1", tbl_name: "tbl_name1", rootpage: 111, sql: "sql1"},
    #   {type: "type2", name: "name2", tbl_name: "tbl_name2", rootpage: 222, sql: "sql2"},
    # ]
    def get_records
      @records = [] # TODO: This should not be a instance variable if we use this scanner multiple times.
      # page content begins from `first_offset` in the page.
      first_offset = @page_size * @root_page_index
      first_offset += HEADER_LENGTH if @root_page_index == 0

      page_typ_offset = first_offset + BTREE_PAGE_TYPE_OFFSET_IN_PAGE
      @file.seek(self.file_offset_from_page_offset(@root_page_index, page_typ_offset))
      page_type = @file.read(BTREE_PAGE_TYPE_LENGTH_IN_PAGE).unpack("C")[0] # C: unsigned char (8-bit) in network byte order (= big-endian)

      raise StandardError.new("Page type: #{page_type} is not for a node in B-tree table.") unless [0x05, 0x0d].include?(page_type)

      if page_type == 0x0d # a leaf table b-tree page
        self.append_records_in_leaf_table_node(@root_page_index)
      end

      # TODO: diverge and go down till it reaches all the leaves.

      @records
    end

    private

    def append_records_in_leaf_table_node(page_index)
      first_offset = @page_size * @root_page_index
      first_offset += HEADER_LENGTH if @root_page_index == 0

      num_cells = 12 # TODO: Fetch this from the offset 3-4 in this page header
      # cell_content_area_offset = 24 # from first_offset   # TODO: Fetch this from the offset 5-6 in this page header

      num_cells.times do |nth_cell|
        cell_pointer_offset = 12 + nth_cell * 2
        @file.seek(file_offset_from_page_offset(@root_page_index, first_offset + cell_pointer_offset))
        cell_offset = @file.read(2).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

        @file.seek(file_offset_from_page_offset(@root_page_index, first_offset + cell_offset))
        # read 1st var-int = #bytes in this cell
        # read 2st var-int = row id

        cell_payload_offset = cell_offset + 2 # or more

        col_to_serial_type = {}

        @columns.each_with_index do |col_name, nth_col|
          # type encoding
          col_serial_type_offset = cell_payload_offset + nth_col * 1 # assuming that there is no super long BLOB/TEXT
          @file.seek(file_offset_from_page_offset(@root_page_index, first_offset + col_serial_type_offset))
          col_serial_type = @file.read(1).unpack("C")[0] # C: unsigned char (8-bit) in network byte order (= big-endian)
          col_to_serial_type[col_name] = col_serial_type
        end

        record = {}

        col_to_serial_type.each do |col, serial_type|
          # read x bytes forward and convert it to the value (depending on serial_type)
          col_value = "table_name_x"
          record[col] = col_value
        end

        @records << record
      end
    end

    def file_offset_from_page_offset(page_index, page_offset)
      @page_size * page_index + page_offset
    end
  end
end
