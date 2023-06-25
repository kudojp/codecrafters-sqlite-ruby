RSpec.describe SimplestSqlParser::LexicalScanner do
  let(:scanner) { described_class.new }

  context "when a query includes SELECT, FROM statements" do
    it "tokenizes the query" do
      scanner.scan_setup("SELECT name FROM table")
      expect(scanner.next_token).to eq [:SELECT, "SELECT"]
      expect(scanner.next_token).to eq [:IDENTIFIER, "name"]
      expect(scanner.next_token).to eq [:FROM, "FROM"]
      expect(scanner.next_token).to eq [:IDENTIFIER, "table"]
      expect(scanner.next_token).to eq nil
    end

    it "tokenizes the query" do
      scanner.scan_setup("SELECT name, address FROM table")
      expect(scanner.next_token).to eq [:SELECT, "SELECT"]
      expect(scanner.next_token).to eq [:IDENTIFIER, "name"]
      expect(scanner.next_token).to eq [:COMMA, ","]
      expect(scanner.next_token).to eq [:IDENTIFIER, "address"]
      expect(scanner.next_token).to eq [:FROM, "FROM"]
      expect(scanner.next_token).to eq [:IDENTIFIER, "table"]
      expect(scanner.next_token).to eq nil
    end

    it "tokenizes the query" do
      scanner.scan_setup("SELECT * FROM table")
      expect(scanner.next_token).to eq [:SELECT, "SELECT"]
      expect(scanner.next_token).to eq [:ASTERISK, "*"]
      expect(scanner.next_token).to eq [:FROM, "FROM"]
      expect(scanner.next_token).to eq [:IDENTIFIER, "table"]
      expect(scanner.next_token).to eq nil
    end
  end

  context "even when a keyword in a query is not capitalized" do
    it "tokenizes the query" do
      scanner.scan_setup("select name FRom table")
      expect(scanner.next_token).to eq [:SELECT, "select"]
      expect(scanner.next_token).to eq [:IDENTIFIER, "name"]
      expect(scanner.next_token).to eq [:FROM, "FRom"]
      expect(scanner.next_token).to eq [:IDENTIFIER, "table"]
      expect(scanner.next_token).to eq nil
    end
  end

  context "when a query includes WHERE statement" do
    it "tokenizes the query" do
      scanner.scan_setup("SELECT name, address FROM table WHERE city = 'TOKYO'")
      expect(scanner.next_token).to eq [:SELECT, "SELECT"]
      expect(scanner.next_token).to eq [:IDENTIFIER, "name"]
      expect(scanner.next_token).to eq [:COMMA, ","]
      expect(scanner.next_token).to eq [:IDENTIFIER, "address"]
      expect(scanner.next_token).to eq [:FROM, "FROM"]
      expect(scanner.next_token).to eq [:IDENTIFIER, "table"]
      expect(scanner.next_token).to eq [:WHERE, "WHERE"]
      expect(scanner.next_token).to eq [:IDENTIFIER, "city"]
      expect(scanner.next_token).to eq [:EQUALS, "="]
      expect(scanner.next_token).to eq [:SINGLE_QUOTE, "'"]
      expect(scanner.next_token).to eq [:IDENTIFIER, "TOKYO"]
      expect(scanner.next_token).to eq [:SINGLE_QUOTE, "'"]
      expect(scanner.next_token).to eq nil
    end
  end

  context "when a query includes COUNT function" do
    it "tokenizes the query" do
      scanner.scan_setup("SELECT COUNT(*) FROM table WHERE id = 12.5")
      expect(scanner.next_token).to eq [:SELECT, "SELECT"]
      expect(scanner.next_token).to eq [:COUNT, "COUNT"]
      expect(scanner.next_token).to eq [:PARENTHESIS_LEFT, "("]
      expect(scanner.next_token).to eq [:ASTERISK, "*"]
      expect(scanner.next_token).to eq [:PARENTHESIS_RIGHT, ")"]
      expect(scanner.next_token).to eq [:FROM, "FROM"]
      expect(scanner.next_token).to eq [:IDENTIFIER, "table"]
      expect(scanner.next_token).to eq [:WHERE, "WHERE"]
      expect(scanner.next_token).to eq [:IDENTIFIER, "id"]
      expect(scanner.next_token).to eq [:EQUALS, "="]
      expect(scanner.next_token).to eq [:IDENTIFIER, 12.5]
      expect(scanner.next_token).to eq nil
    end
  end
end
