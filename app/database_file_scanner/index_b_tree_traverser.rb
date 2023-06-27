require 'set'

class DatabaseFileScanner
  class IndexBTreeTraverser
    BTREE_PAGE_TYPE_OFFSET_IN_PAGE = 0
    BTREE_PAGE_TYPE_LENGTH_IN_PAGE = 1
    NUM_CELLS_OFFSET_IN_PAGE = 3
    NUM_CELLS_LENGTH_IN_PAGE = 2
    RIGHTMOST_CHILD_POINTER_OFFSET_IN_INTERIOR_PAGE = 8
    RIGHTMOST_CHILD_POINTER_LENGTH_IN_INTERIOR_PAGE = 4
    HEADER_LENGTH_IN_LEAF_PAGE = 8
    HEADER_LENGTH_IN_INTERIOR_PAGE = 12

    def initialize(file, page_size, root_page_index, lambda_is_key_in_left_child_pages)
      @file = file
      @page_size = page_size
      @root_page_index = root_page_index
      # At each interior pages, this lambda function is used to decide which child page to go down.
      @lambda_is_key_in_left_child_pages = lambda_is_key_in_left_child_pages
    end

    # This returns a list of page indexes of table leaf node where the keys you are looking for exist.
    def get_page_indexes_of_table_records
      @page_indexes_of_table_records = Set.new
      self.traverse_to_find_page_indexes_of_table_records(page_index: @root_page_index)
      print "## page_indexes_of_table_records: #{@page_indexes_of_table_records} ##\n"
      @page_indexes_of_table_records
    end

    private

    def traverse_to_find_page_indexes_of_table_records(page_index:)
      first_offset = 0 # from the beginning of this page
      first_offset += HEADER_LENGTH if page_index == 1 # pages are 1-indexed.

      @file.seek(self.file_offset_from_page_offset(page_index, first_offset + BTREE_PAGE_TYPE_OFFSET_IN_PAGE))
      page_type = @file.read(BTREE_PAGE_TYPE_LENGTH_IN_PAGE).unpack("C")[0] # C: unsigned char (8-bit) in network byte order (= big-endian)

      if page_type == 0x0a # a leaf index b-tree page
        self.append_page_indexes_in_leaf_index_node(page_index)
        return
      end

      if page_type == 0x02 # an interior index b-tree page
        self.child_page_indexes(page_index).each do |child_page_index|
          self.traverse_to_find_page_indexes_of_table_records(page_index: child_page_index)
        end
        return
      end

      raise StandardError.new("Page type: #{page_type} of page (#{page_index}) is not for a node in B-tree index.")
    end

    def append_page_indexes_in_leaf_index_node(page_index)
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

        cell_payload_size_offset = cell_offset
        payload_size, used_bytes = VarIntScanner.new(@file, file_offset_from_page_offset(page_index, cell_payload_size_offset)).read
        cell_payload_offset = cell_payload_size_offset + used_bytes

        # Type encodings for 2 values
        type_encodings = []
        curr_offset = cell_payload_offset
        2.times do
          @file.seek(file_offset_from_page_offset(page_index, curr_offset))
          col_serial_type, used_bytes = VarIntScanner.new(@file, file_offset_from_page_offset(page_index, curr_offset)).read
          type_encodings << serial_type(col_serial_type)
          curr_offset += used_bytes
        end

        # Value encodings for each column
        type_encodings.each_with_index do |(used_bytes, read_lambda), i|
          @file.seek(file_offset_from_page_offset(page_index, curr_offset))
          value = read_lambda.call(@file)
          @page_indexes_of_table_records << value if i == 0
          curr_offset += used_bytes
        end
      end
    end

    def child_page_indexes(page_index)
      first_offset = 0
      first_offset += HEADER_LENGTH if page_index == 1 # pages are 1-indexed.

      @file.seek(self.file_offset_from_page_offset(page_index, first_offset + NUM_CELLS_OFFSET_IN_PAGE))
      num_cells = @file.read(NUM_CELLS_LENGTH_IN_PAGE).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

      child_page_indexes = []

      # For each record,,,
      num_cells.times do |nth_cell|
        cell_pointer_offset = HEADER_LENGTH_IN_INTERIOR_PAGE + nth_cell * 2 # from first_offset
        @file.seek(file_offset_from_page_offset(page_index, first_offset + cell_pointer_offset))
        # This cell_offset is from index=0 in this page, not from first_offset.
        cell_offset = @file.read(2).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

        left_child_ptr_offset = cell_offset
        @file.seek(file_offset_from_page_offset(page_index, left_child_ptr_offset))
        left_child_page_index = @file.read(4).unpack("N")[0] # N: big endian unsigned 32bit
        payload_size_offset = left_child_ptr_offset + 4

        @file.seek(file_offset_from_page_offset(page_index, payload_size_offset))
        payload_size, used_bytes = VarIntScanner.new(@file, file_offset_from_page_offset(page_index, cell_offset+4)).read
        payload_offset = payload_size_offset + used_bytes

        @file.seek(payload_offset)
        key = @file.read(payload_size) # Assuming that there is no overflow.

        if @lambda_is_key_in_left_child_pages.call(key)
          child_page_indexes << left_child_page_index
          return child_page_indexes
        end
      end

      @file.seek(self.file_offset_from_page_offset(page_index, first_offset + RIGHTMOST_CHILD_POINTER_OFFSET_IN_INTERIOR_PAGE))
      rightmost_child_page_index = @file.read(RIGHTMOST_CHILD_POINTER_LENGTH_IN_INTERIOR_PAGE).unpack("N")[0] # N: big endian unsigned 32bit

      child_page_indexes << rightmost_child_page_index
      return child_page_indexes
    end

    def file_offset_from_page_offset(page_index, page_offset)
      # pages are 1-indexed
      @page_size * (page_index - 1) + page_offset
    end

    # Returns an array of [bytes used for that value, lambda function to read from a given file]
    def serial_type(serial_type)
      # blob
      if (12 <= serial_type) && (serial_type % 2 == 0)
        byte_length = (serial_type-12)/2
        return byte_length, lambda{|file| file.read(byte_length).unpack("a*")[0]}
      end

      # text
      if (13 <= serial_type) && (serial_type % 2 == 1)
        byte_length = (serial_type-13)/2
        return byte_length, lambda{|file| file.read(byte_length).unpack("a*")[0]}
      end

      # TODO: add key=0~11 here.
      mapping = {
        0 => [0, lambda{|_file| nil}],
        1 => [1, lambda{|file| file.read(1).unpack("C")[0]}], # C: unsigned char (8-bit) in network byte order (= big-endian)
        2 => [2, lambda{|file| file.read(2).unpack("n")[0]}], # n: big endian unsigned 16bit
        3 => [3, lambda{|file|                                #    big-endian 24-bit twos-complement integer.
          # ref. https://dormolin.livedoor.blog/archives/52185510.html
          puts "@@@@@@@@@ WARNING(index traverser): This should be fixed @@@@@@@@@"
          3
        }],
        4 => [4, lambda{|file| file.read(4).unpack("N")[0]}], # N: big endian unsigned 32bit
        9 => [0, lambda{|_file| 1}]
      }
      mapping.fetch(serial_type)
    end
  end
end
