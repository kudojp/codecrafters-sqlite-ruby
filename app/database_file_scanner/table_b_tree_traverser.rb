class DatabaseFileScanner
  class TableBTreeTraverser
    BTREE_PAGE_TYPE_OFFSET_IN_PAGE = 0
    BTREE_PAGE_TYPE_LENGTH_IN_PAGE = 1
    NUM_CELLS_OFFSET_IN_PAGE = 3
    NUM_CELLS_LENGTH_IN_PAGE = 2
    HEADER_LENGTH_IN_LEAF_PAGE = 8

    def initialize(file, page_size, root_page_index, columns=nil)
      @file = file
      @page_size = page_size
      @root_page_index = root_page_index
      @columns = columns
    end

    def cnt_records
      first_offset = 0 # from the beginning of this page
      first_offset += HEADER_LENGTH if @root_page_index == 1 # pages are 1-indexed.

      @file.seek(self.file_offset_from_page_offset(@root_page_index, first_offset + BTREE_PAGE_TYPE_OFFSET_IN_PAGE))
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
      raise StandardError.new("Set columns when initializing this scanner to call #get_records") unless @columns

      @records = [] # TODO: This should not be a instance variable if we use this scanner multiple times.
      first_offset = 0 # from the beginning of this page
      first_offset += HEADER_LENGTH if @root_page_index == 1 # pages are 1-indexed.

      @file.seek(self.file_offset_from_page_offset(@root_page_index, first_offset + BTREE_PAGE_TYPE_OFFSET_IN_PAGE))
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
      first_offset = 0
      first_offset += HEADER_LENGTH if page_index == 1 # pages are 1-indexed.

      @file.seek(self.file_offset_from_page_offset(page_index, first_offset + NUM_CELLS_OFFSET_IN_PAGE))
      num_cells = @file.read(NUM_CELLS_LENGTH_IN_PAGE).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

      # For each record,,,
      num_cells.times do |nth_cell|
        cell_pointer_offset = HEADER_LENGTH_IN_LEAF_PAGE + nth_cell * 2 # from first_offset
        @file.seek(file_offset_from_page_offset(page_index, first_offset + cell_pointer_offset))
        # This cell_offset is from index=0 in this page, not from first_offset.
        cell_offset = @file.read(2).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

        cell_payload_size_offset = cell_offset # from index=0 in this page
        _payload_size, used_bytes = VarIntScanner.new(@file, file_offset_from_page_offset(page_index, cell_payload_size_offset)).read
        cell_row_id_offset = cell_payload_size_offset + used_bytes

        _row_id, used_bytes = VarIntScanner.new(@file, file_offset_from_page_offset(page_index, cell_row_id_offset)).read
        cell_payload_offset = cell_row_id_offset + used_bytes

        cell_payload_offset += 1 # I don't know what this 1 byte is.

        col_to_serial_type = {}
        curr_offset = cell_payload_offset

        # Type encodings for each column
        @columns.each_with_index do |col_name, nth_col|
          @file.seek(file_offset_from_page_offset(page_index, curr_offset))
          col_serial_type, used_bytes = VarIntScanner.new(@file, file_offset_from_page_offset(page_index, curr_offset)).read
          col_to_serial_type[col_name] = serial_type(col_serial_type)
          curr_offset += used_bytes
        end

        record = {}
        # Value encodings for each column
        col_to_serial_type.each do |col, (used_bytes, read_lambda)|
          @file.seek(curr_offset)
          col_value = read_lambda.call(@file)
          record[col] = col_value
          curr_offset += used_bytes
        end

        @records << record
      end
    end

    # Returns an array of [bytes used for that value, lambda function to read from a given file]
    def serial_type(serial_type)
      # blob
      if (12 <= serial_type) && (serial_type % 2 == 0)
        byte_length = (serial_type-12)/2
        return byte_length, lambda{|file| file.read(byte_length).unpack("a*")[0]}
      end

      if (13 <= serial_type) && (serial_type % 2 == 1)
        byte_length = (serial_type-13)/2
        return byte_length, lambda{|file| file.read(byte_length).unpack("a*")[0]}
      end

      # TODO: add key=0~11 here.
      mapping = {
        1 => [1, lambda{|file| file.read(byte_length).unpack("C")[0]}], # C: unsigned char (8-bit) in network byte order (= big-endian)
      }
      mapping.fetch(serial_type)
    end

    def file_offset_from_page_offset(page_index, page_offset)
      # pages are 1-indexed
      @page_size * (page_index - 1) + page_offset
    end
  end
end
