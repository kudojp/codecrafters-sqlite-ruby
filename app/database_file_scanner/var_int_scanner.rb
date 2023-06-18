class DatabaseFileScanner
  class VarIntScanner
    # Returns (the integer value, number of bytes used in the file)
    def initialize(file, offset)
      @file = file
      @offset = offset
    end

    def read
      value = 0
      8.times do |nth_byte|
        @file.seek(@offset + nth_byte)
        val = @file.read(1).unpack("C")[0]

        first_bit = val / 2**7
        last_7_bits = val % 2**7

        value += last_7_bits
        return value, nth_byte + 1 if first_bit == 0 # here is the last bit.
        value *= 2**7
      end

      value *= 2 # 8 bits (not 7) can be used in the final byte.
      @file.seek(@offset + 8)
      value += @file.read(1).unpack("C")[0]
      [value, 9]
    end
  end
end
