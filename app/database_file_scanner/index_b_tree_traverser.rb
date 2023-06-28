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

    def initialize(file:, page_size:)
      @file = file
      @page_size = page_size
    end

    # This returns a list of page indexes of table leaf node where the keys you are looking for exist.
    def get_rowids(root_page_index:, searching_key:)
      @rowids = Set.new
      self.search_in_tree(root_page_index: root_page_index, searching_key: searching_key)
      @rowids
    end

    private

    def search_in_tree(root_page_index:, searching_key:)
      first_offset = 0 # from the beginning of this page
      first_offset += HEADER_LENGTH if root_page_index == 1 # pages are 1-indexed.

      @file.seek(self.file_offset_from_page_offset(root_page_index, first_offset + BTREE_PAGE_TYPE_OFFSET_IN_PAGE))
      page_type = @file.read(BTREE_PAGE_TYPE_LENGTH_IN_PAGE).unpack("C")[0] # C: unsigned char (8-bit) in network byte order (= big-endian)

      if page_type == 0x0a # a leaf index b-tree page
        self.search_in_leaf(page_index: root_page_index, searching_key: searching_key)
        return
      end

      if page_type == 0x02 # an interior index b-tree page
        self.child_page_indexes(page_index: root_page_index, searching_key: searching_key).each do |child_page_index|
          self.search_in_tree(root_page_index: child_page_index, searching_key: searching_key)
        end
        return
      end

      raise StandardError.new("Page type: #{page_type} of page (#{root_page_index}) is not for a node in B-tree index.")
    end

    def search_in_leaf(page_index:, searching_key:)
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
        _payload_size, used_bytes = VarIntScanner.new(@file, file_offset_from_page_offset(page_index, cell_payload_size_offset)).read
        cell_payload_offset = cell_payload_size_offset + used_bytes

        curr_offset = cell_payload_offset + 1 # I don't know what this 1 byte is.

        # Payload
        ### encoding of `key`
        @file.seek(file_offset_from_page_offset(page_index, curr_offset))
        key_serial_type, used_bytes = VarIntScanner.new(@file, file_offset_from_page_offset(page_index, curr_offset)).read
        key_byte_length, key_read_lambda = serial_type(key_serial_type)
        curr_offset += used_bytes

        ### encoding of `rowid`
        @file.seek(file_offset_from_page_offset(page_index, curr_offset))
        rowid_serial_type, used_bytes = VarIntScanner.new(@file, file_offset_from_page_offset(page_index, curr_offset)).read
        rowid_byte_length, rowid_read_lambda = serial_type(rowid_serial_type)
        curr_offset += used_bytes

        ### value of `key`
        @file.seek(file_offset_from_page_offset(page_index, curr_offset))
        key = key_read_lambda.call(@file)
        curr_offset += key_byte_length

        next unless key == searching_key

        ### value of `rowid`
        @file.seek(file_offset_from_page_offset(page_index, curr_offset))
        rowid = rowid_read_lambda.call(@file)

        @rowids << rowid
      end
    end

    def child_page_indexes(page_index:, searching_key:)
      first_offset = 0
      first_offset += HEADER_LENGTH if page_index == 1 # pages are 1-indexed.

      @file.seek(self.file_offset_from_page_offset(page_index, first_offset + NUM_CELLS_OFFSET_IN_PAGE))
      num_cells = @file.read(NUM_CELLS_LENGTH_IN_PAGE).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

      ret = []
      # For each record,,,
      num_cells.times do |nth_cell|
        # Cell pointer to cell content
        cell_pointer_offset = HEADER_LENGTH_IN_INTERIOR_PAGE + nth_cell * 2 # from first_offset
        @file.seek(file_offset_from_page_offset(page_index, first_offset + cell_pointer_offset))
        # This cell_offset is from index=0 in this page, not from first_offset.
        left_child_ptr_offset = @file.read(2).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

        # (4-byte integer) Page number of left child
        @file.seek(file_offset_from_page_offset(page_index, left_child_ptr_offset))
        left_child_page_index = @file.read(4).unpack("N")[0] # N: big endian unsigned 32bit
        payload_size_offset = left_child_ptr_offset + 4

        # (varint) Number of bytes of payload
        payload_size, used_bytes = VarIntScanner.new(@file, file_offset_from_page_offset(page_index, payload_size_offset)).read
        payload_offset = payload_size_offset + used_bytes

        payload_offset += 1 # I don't know what this is.

        # payload
        ###  encoding type of key
        @file.seek(file_offset_from_page_offset(page_index, payload_offset))
        key_serial_type, used_bytes = VarIntScanner.new(@file, file_offset_from_page_offset(page_index, payload_offset)).read
        key_offset = payload_offset + used_bytes

        key_offset += 1 # I don't know what this is.

        ### encoding value of `key`
        _key_byte_length, key_read_lambda = serial_type(key_serial_type)
        @file.seek(file_offset_from_page_offset(page_index, key_offset))
        key = @file.read(_key_byte_length)

        ## You are searching for 15, then
        #----------------------------------------
        #     15   18   18
        #   o    o    x     x
        #----------------------------------------
        #    9    11   15
        #  x    x    x    o
        #----------------------------------------
        #    9    15   15   16
        #  x   o     o    o    x
        #----------------------------------------
        #    18   20
        #  o    x    x
        # ---------------------------------------
        ret << left_child_page_index if searching_key <= key
        return ret if searching_key < key
      end

      @file.seek(self.file_offset_from_page_offset(page_index, first_offset + RIGHTMOST_CHILD_POINTER_OFFSET_IN_INTERIOR_PAGE))
      rightmost_child_page_index = @file.read(RIGHTMOST_CHILD_POINTER_LENGTH_IN_INTERIOR_PAGE).unpack("N")[0] # N: big endian unsigned 32bit
      ret << rightmost_child_page_index
      ret
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
          "\x00#{file.read(3)}".unpack("N")[0]
        }],
        4 => [4, lambda{|file| file.read(4).unpack("N")[0]}], # N: big endian unsigned 32bit
        9 => [0, lambda{|_file| 1}]
      }
      mapping.fetch(serial_type)
    end
  end
end
