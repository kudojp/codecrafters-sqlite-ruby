require 'rspec'
require './app/database_file_scanner/var_int_scanner'

RSpec.describe DatabaseFileScanner::VarIntScanner do
  let(:varint_start_index){ 0 }

  before do
    File.open(file_path, "wb") do |file|
      # Since varint_start_index = 0, write the varint from the beginning of the file.
      file.write(varint_var.pack("C*"))
      file.write([0b10010101, 0b01010010].pack("C*")) # no meaning and no use
    end
  end


  context "when the encoded varint is 1-byte long" do
    let(:file_path){ "./spec/fixtures/var_int_1byte.bin" }
    let(:varint_var){ [0b00000001] }

    it "converts to int correctly" do
      File.open(file_path, "rb") do |file|
        scanner = described_class.new(file, varint_start_index)

        int_value, used_bytes = scanner.read()
        expect(int_value).to eq(1)
        expect(used_bytes).to eq(1)
      end
    end
  end

  context "when the encoded varint is 2-byte long" do
    let(:file_path){ "./spec/fixtures/var_int_2byte.bin" }
    let(:varint_var){ [0b10000001, 0b00000001] }

    it "converts to int correctly" do
      File.open(file_path, "rb") do |file|
        scanner = described_class.new(file, varint_start_index)

        int_value, used_bytes = scanner.read()
        expect(int_value).to eq(129)
        expect(used_bytes).to eq(2)
      end
    end
  end

  context "when the encoded varint is 9-byte long (full length)" do
    let(:file_path){ "./spec/fixtures/var_int_9byte.bin" }
    let(:varint_var){ [0b10000001] + [0b10000000] * 7 + [0b00000001] }

    it "converts to int correctly" do
      File.open(file_path, "rb") do |file|
        scanner = described_class.new(file, varint_start_index)

        int_value, used_bytes = scanner.read()
        expect(int_value).to eq(2 ** 57 + 1)
        expect(used_bytes).to eq(9)
      end
    end
  end
end
