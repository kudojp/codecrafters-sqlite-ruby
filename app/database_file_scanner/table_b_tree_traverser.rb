class DatabaseFileScanner
  class TableBTreeTraverser
    BTREE_PAGE_TYPE_OFFSET_IN_PAGE = 0
    BTREE_PAGE_TYPE_LENGTH_IN_PAGE = 1
    NUM_CELLS_OFFSET_IN_PAGE = 3
    NUM_CELLS_LENGTH_IN_PAGE = 2
    RIGHTMOST_CHILD_POINTER_OFFSET_IN_INTERIOR_PAGE = 8
    RIGHTMOST_CHILD_POINTER_LENGTH_IN_INTERIOR_PAGE = 4
    HEADER_LENGTH_IN_LEAF_PAGE = 8
    HEADER_LENGTH_IN_INTERIOR_PAGE = 12

    def initialize(file:, page_size:)
      @file = file
      @page_size = page_size
      # @root_page_index = root_page_index
    end

    def cnt_records_in_table(root_page_index:)
      page = fetch_page(page_index: root_page_index)

      first_offset = 0 # from the beginning of this page
      first_offset += HEADER_LENGTH if root_page_index == 1 # pages are 1-indexed.

      page_type = fetch_bytes_in_page(
        page: page,
        offset: first_offset + BTREE_PAGE_TYPE_OFFSET_IN_PAGE,
        length: BTREE_PAGE_TYPE_LENGTH_IN_PAGE,
      ).unpack("C")[0] # C: unsigned char (8-bit) in network byte order (= big-endian)

      if page_type == 0x0d # a leaf table b-tree page
        num_cells = fetch_bytes_in_page(
          page: page,
          offset: first_offset + NUM_CELLS_OFFSET_IN_PAGE,
          length: NUM_CELLS_LENGTH_IN_PAGE,
        ).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

        return num_cells
      end

      if page_type == 0x05 # an interior table b-tree page
        # TODO: go down the b-tree recursively.
        raise StandardError.new("Not implemented yet!")
      end

      raise StandardError.new("Page type: #{page_type} of page (#{root_page_index}) is not for a node in B-tree table.") 
    end

    # Returns an array structured like:
    # [
    #   {type: "type1", name: "name1", tbl_name: "tbl_name1", rootpage: 111, sql: "sql1"},
    #   {type: "type2", name: "name2", tbl_name: "tbl_name2", rootpage: 222, sql: "sql2"},
    # ]
    def get_records_in_table(root_page_index:, columns:, primary_index_key:, pk_values: nil)
      if !primary_index_key.nil? && !columns.include?(primary_index_key)
        raise StandardError.new("You specified #{primary_index_key} as a primary key, but it is not included in columns #{columns}.")
      end

      if !primary_index_key && pk_values
        raise StandardError.new("You specified pk_values, but you did not specify primary_index_key.")
      end

      @records_in_table = []
      self.collect_in_tree(page_index: root_page_index, columns: columns, primary_index_key: primary_index_key, pk_values: pk_values)
      @records_in_table
    end

    private

    # TODO this can be included in #get_records_in_table
    def collect_in_tree(page_index:, columns:, primary_index_key:, pk_values:)
      page = fetch_page(page_index: page_index)

      first_offset = 0 # from the beginning of this page
      first_offset += HEADER_LENGTH if page_index == 1 # pages are 1-indexed.

      page_type = fetch_bytes_in_page(
        page: page,
        offset: first_offset + BTREE_PAGE_TYPE_OFFSET_IN_PAGE,
        length: BTREE_PAGE_TYPE_LENGTH_IN_PAGE,
      ).unpack("C")[0] # C: unsigned char (8-bit) in network byte order (= big-endian)

      if page_type == 0x0d # a leaf table b-tree page
        @records_in_table += self.collect_in_leaf(leaf_page_index: page_index, columns: columns, primary_index_key: primary_index_key, pk_values: pk_values)
        return
      end

      if page_type == 0x05 # an interior table b-tree page
        child_page_indexes(page_index: page_index, pk_values: pk_values).each do |child_page_index, child_pk_values|
          self.collect_in_tree(page_index: child_page_index, columns: columns, primary_index_key: primary_index_key, pk_values: child_pk_values)
        end
        return
      end

      raise StandardError.new("Page type: #{page_type} is not for a node in B-tree table.")
    end

    def collect_in_leaf(leaf_page_index:, columns:, primary_index_key:, pk_values:)
      page = fetch_page(page_index: leaf_page_index)

      first_offset = 0 # from the beginning of this page
      first_offset += HEADER_LENGTH if leaf_page_index == 1 # pages are 1-indexed.

      page_type = fetch_bytes_in_page(
        page: page,
        offset: first_offset + BTREE_PAGE_TYPE_OFFSET_IN_PAGE,
        length: BTREE_PAGE_TYPE_LENGTH_IN_PAGE,
      ).unpack("C")[0] # C: unsigned char (8-bit) in network byte order (= big-endian)

      unless page_type == 0x0d
        raise StandardError.new("Page #{leaf_page_index} (page_type=#{page_type}) is not a table leaf. ")
      end

      first_offset = 0
      first_offset += HEADER_LENGTH if leaf_page_index == 1 # pages are 1-indexed.

      num_cells = fetch_bytes_in_page(
        page: page,
        offset: first_offset + NUM_CELLS_OFFSET_IN_PAGE,
        length: NUM_CELLS_LENGTH_IN_PAGE,
      ).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

      records_in_leaf = []
      # For each record,,,
      num_cells.times do |nth_cell|
        cell_pointer_offset = HEADER_LENGTH_IN_LEAF_PAGE + nth_cell * 2 # from first_offset

        cell_offset = fetch_bytes_in_page(
          page: page,
          offset: first_offset + cell_pointer_offset,
          length: 2,
        ).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

        cell_payload_size_offset = cell_offset # from index=0 in this page
        _payload_size, used_bytes = VarIntScanner.new(page[cell_payload_size_offset...]).read
        cell_rowid_offset = cell_payload_size_offset + used_bytes

        rowid, used_bytes = VarIntScanner.new(page[cell_rowid_offset...]).read
        cell_payload_offset = cell_rowid_offset + used_bytes

        next if pk_values && !pk_values.include?(rowid)

        cell_payload_offset += 1 # I don't know what this 1 byte is.

        col_to_serial_type = {}
        curr_offset = cell_payload_offset

        # Type encodings for each column
        columns.each_with_index do |col_name, nth_col|
          col_serial_type, used_bytes = VarIntScanner.new(page[curr_offset..]).read
          col_to_serial_type[col_name] = serial_type(col_serial_type)
          curr_offset += used_bytes
        end

        record = {}
        # Value encodings for each column
        col_to_serial_type.each do |col, (used_bytes, read_lambda)|
          record[col] =
            if col == primary_index_key
              rowid
            else
              read_lambda.call(page[curr_offset..])
            end
          curr_offset += used_bytes
        end

        records_in_leaf << record
      end

      records_in_leaf
    end

    def child_page_indexes(page_index:, pk_values:)
      page = fetch_page(page_index: page_index)

      first_offset = 0
      first_offset += HEADER_LENGTH if page_index == 1 # pages are 1-indexed.

      num_cells = fetch_bytes_in_page(
        page: page,
        offset: first_offset + NUM_CELLS_OFFSET_IN_PAGE,
        length: NUM_CELLS_LENGTH_IN_PAGE,
      ).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

      child_page_indexes = []

      # For each record,,,
      prev_rowid = -1
      num_cells.times do |nth_cell|
        cell_pointer_offset = HEADER_LENGTH_IN_INTERIOR_PAGE + nth_cell * 2 # from first_offset

        cell_offset = fetch_bytes_in_page(
          page: page,
          offset: first_offset + cell_pointer_offset,
          length: 2,
        ).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

        child_page_index = fetch_bytes_in_page(
          page: page,
          offset: cell_offset,
          length: 4,
        ).unpack("N")[0] # N: big endian unsigned 32bit

        rowid_index = cell_offset + 4
        rowid, used_bytes = VarIntScanner.new(page[rowid_index..]).read

        ## You are searching for rowid=[13,14,15], then
        #----------------------------------------
        #     12   14   16
        #   x    o    o     x
        #----------------------------------------
        #    13   14   17
        #   o    o    o    x
        #----------------------------------------
        #    13   14   15
        #  o    o    o    o
        #----------------------------------------
        #    18   20
        #  o    x    x
        # ---------------------------------------
        if pk_values
          pk_values_in_child = pk_values.select{|pk_value| prev_rowid <= pk_value && pk_value <= rowid}
          child_page_indexes << [child_page_index, pk_values_in_child] if pk_values_in_child.length > 0
          return child_page_indexes if pk_values.max() < rowid
          prev_rowid = rowid
        else
          child_page_indexes << [child_page_index, nil]
        end
      end

      rightmost_child_page_index = fetch_bytes_in_page(
        page: page,
        offset: first_offset + RIGHTMOST_CHILD_POINTER_OFFSET_IN_INTERIOR_PAGE,
        length: RIGHTMOST_CHILD_POINTER_LENGTH_IN_INTERIOR_PAGE,
      ).unpack("N")[0] # N: big endian unsigned 32bit

      if pk_values
        pk_values_in_child = pk_values.select{|pk_value| rightmost_child_page_index <= pk_value}
        child_page_indexes << [rightmost_child_page_index, pk_values_in_child] if pk_values_in_child.length > 0
      else
        child_page_indexes << [rightmost_child_page_index, nil]
      end
      child_page_indexes
    end

    def fetch_page(page_index:)
      @file.seek(@page_size * (page_index - 1))
      @file.read(@page_size)
    end

    def fetch_bytes_in_page(page:, offset:, length:)
      page[offset...(offset + length)]
    end

    # Returns an array of [bytes used for that value, lambda function to read from a given file]
    def serial_type(serial_type)
      # blob
      if (12 <= serial_type) && (serial_type % 2 == 0)
        byte_length = (serial_type-12)/2
        return byte_length, lambda{|bytes| bytes[...byte_length].unpack("a*")[0]}
      end

      # text
      if (13 <= serial_type) && (serial_type % 2 == 1)
        byte_length = (serial_type-13)/2
        return byte_length, lambda{|bytes| bytes[...byte_length].unpack("a*")[0]}
      end

      # TODO: add key=0~11 here.
      mapping = {
        0 => [0, lambda{|_bytes| nil}],
        1 => [1, lambda{|bytes| bytes[...1].unpack("C")[0]}], # C: unsigned char (8-bit) in network byte order (= big-endian)
        2 => [2, lambda{|bytes| bytes[...2].unpack("n")[0]}], # n: big endian unsigned 16bit
        3 => [3, lambda{|bytes|                                #    big-endian 24-bit twos-complement integer.
          # ref. https://dormolin.livedoor.blog/archives/52185510.html
          "\x00#{bytes[...3]}".unpack("N")[0]
        }],
        4 => [4, lambda{|bytes| bytes[...4].unpack("N>")[0]}], # N: big endian unsigned 32bit
        6 => [6, lambda{|bytes| bytes[...6].unpack("q>")[0]}], # N: big endian unsigned 64bit
        9 => [0, lambda{|_bytes| 1}]
      }
      mapping.fetch(serial_type)
    end

    def file_offset_from_page_offset(page_index, page_offset)
      # pages are 1-indexed
      @page_size * (page_index - 1) + page_offset
    end
  end
end
