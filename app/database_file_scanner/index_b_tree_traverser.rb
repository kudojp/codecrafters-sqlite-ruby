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

    # This returns a list of rowids in the original table.
    def get_rowids(root_page_index:, searching_key:)
      @rowids = Set.new
      self.search_in_tree(root_page_index: root_page_index, searching_key: searching_key)
      @rowids
    end

    private

    def search_in_tree(root_page_index:, searching_key:)
      page = fetch_page(page_index: root_page_index)

      first_offset = 0 # from the beginning of this page
      first_offset += HEADER_LENGTH if root_page_index == 1 # pages are 1-indexed.

      page_type = fetch_bytes_in_page(
        page: page,
        offset: first_offset + BTREE_PAGE_TYPE_OFFSET_IN_PAGE,
        length: BTREE_PAGE_TYPE_LENGTH_IN_PAGE,
      ).unpack("C")[0] # C: unsigned char (8-bit) in network byte order (= big-endian)

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
      page = fetch_page(page_index: page_index)

      first_offset = 0 # from the beginning of this page

      first_offset = 0
      first_offset += HEADER_LENGTH if page_index == 1 # pages are 1-indexed.

      num_cells = fetch_bytes_in_page(
        page: page,
        offset: first_offset + NUM_CELLS_OFFSET_IN_PAGE,
        length: NUM_CELLS_LENGTH_IN_PAGE,
      ).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

      # For each record,,,
      num_cells.times do |nth_cell|
        cell_pointer_offset = HEADER_LENGTH_IN_LEAF_PAGE + nth_cell * 2 # from first_offset

        cell_offset = fetch_bytes_in_page(
          page: page,
          offset: first_offset + cell_pointer_offset,
          length: 2,
        ).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

        cell_payload_size_offset = cell_offset
        _payload_size, used_bytes = VarIntScanner.new(page[cell_payload_size_offset...]).read
        cell_payload_offset = cell_payload_size_offset + used_bytes

        curr_offset = cell_payload_offset + 1 # I don't know what this 1 byte is.

        # Payload
        ### encoding of `key`
        key_serial_type, used_bytes = VarIntScanner.new(page[curr_offset...]).read
        key_byte_length, key_read_lambda = serial_type(key_serial_type)
        curr_offset += used_bytes

        ### encoding of `rowid`
        rowid_serial_type, used_bytes = VarIntScanner.new(page[curr_offset...]).read
        rowid_byte_length, rowid_read_lambda = serial_type(rowid_serial_type)
        curr_offset += used_bytes

        ### value of `key`
        key = key_read_lambda.call(page[curr_offset...])
        curr_offset += key_byte_length

        next unless key == searching_key

        ### value of `rowid`
        rowid = rowid_read_lambda.call(page[curr_offset...])

        @rowids << rowid
      end
    end

    def child_page_indexes(page_index:, searching_key:)
      page = fetch_page(page_index: page_index)

      first_offset = 0
      first_offset += HEADER_LENGTH if page_index == 1 # pages are 1-indexed.

      num_cells = fetch_bytes_in_page(
        page: page,
        offset: first_offset + NUM_CELLS_OFFSET_IN_PAGE,
        length: NUM_CELLS_LENGTH_IN_PAGE,
      ).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

      ret = []
      # For each record,,,
      num_cells.times do |nth_cell|
        # Cell pointer to cell content
        cell_pointer_offset = HEADER_LENGTH_IN_INTERIOR_PAGE + nth_cell * 2 # from first_offset

        left_child_ptr_offset = fetch_bytes_in_page(
          page: page,
          offset: first_offset + cell_pointer_offset,
          length: 2,
        ).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)

        # (4-byte integer) Page number of left child
        left_child_page_index = fetch_bytes_in_page(
          page: page,
          offset: first_offset + left_child_ptr_offset,
          length: 4,
        ).unpack("N")[0] # N: big endian unsigned 32bit
        payload_size_offset = left_child_ptr_offset + 4

        # (varint) Number of bytes of payload
        payload_size, used_bytes = VarIntScanner.new(page[payload_size_offset...]).read
        payload_offset = payload_size_offset + used_bytes

        payload_offset += 1 # I don't know what this is.

        # payload
        ### type encoding of `key`
        key_serial_type, used_bytes = VarIntScanner.new(page[payload_offset...]).read
        key_offset = payload_offset + used_bytes

        key_offset += 1 # I don't know what this is.

        ### value encoding of `key`
        key_byte_length, key_read_lambda = serial_type(key_serial_type)
        key = fetch_bytes_in_page(
          page: page,
          offset: key_offset,
          length: key_byte_length,
        )[...key_byte_length]

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

      rightmost_child_page_index = fetch_rightmost_child_page_index(
        page: page,
        offset: first_offset + RIGHTMOST_CHILD_POINTER_OFFSET_IN_INTERIOR_PAGE,
        length: RIGHTMOST_CHILD_POINTER_LENGTH_IN_INTERIOR_PAGE
      ).unpack("N")[0] # N: big endian unsigned 32bit

      ret << rightmost_child_page_index
      ret
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
        4 => [4, lambda{|bytes| bytes[...4].unpack("N")[0]}], # N: big endian unsigned 32bit
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
