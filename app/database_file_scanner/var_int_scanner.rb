class DatabaseFileScanner
  class VarIntScanner
    # Returns (the integer value, number of bytes used in the file)
    def initialize(bytes)#, offset)
      @bytes = bytes
    end

    def read
      value = 0
      8.times do |nth_byte|
        val = @bytes[nth_byte, 1].unpack("C")[0]

        first_bit = val / 2**7
        last_7_bits = val % 2**7

        value += last_7_bits
        return value, nth_byte + 1 if first_bit == 0 # here is the last bit.
        value *= 2**7
      end

      value *= 2 # 8 bits (not 7) can be used in the final byte.
      value += bytes[8].unpack("C")[0]
      [value, 9]
    end
  end
end
