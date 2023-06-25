Dir["./app/database/*.rb"].each {|file| require file }
Dir["./app/database_file_scanner/*.rb"].each {|file| require file }

class DatabaseFileScanner
  HEADER_LENGTH = 100 # bytes
  PAGE_SIZE_OFFSET_IN_FILE_HEADER = 16
  PAGE_SIZE_LENGTH_IN_FILE_HEADER = 2
  SQLITE_SCHEMA_PAGE_NUMBER = 1

  def initialize(database_file_path)
    @file = File.open(database_file_path, "rb")
  end

  def header_info
    @header_info = Database::HeaderInfo.new(page_size: page_size)
  end

  def sqlite_schema
    @sqlite_schema ||= get_sqlite_schema
  end

  def count_records(table_name)
    table_info = self.sqlite_schema.tables.find{|tbl| tbl.fetch(:name) == table_name}
    table_root_page_index = table_info.fetch(:rootpage)

    TableBTreeTraverser.new(@file, self.page_size, table_root_page_index).cnt_records
  end

  def get_records(table_name, filtering_cols=nil)
    table_info, table_root_page_index, column_names, col_primary_index_key = get_table_metadata(table_name)
    TableBTreeTraverser.new(@file, self.page_size, table_root_page_index).get_records(column_names, col_primary_index_key)
  end

  private

  def page_size
    @page_size ||= get_page_size
  end

  def get_page_size
    @file.seek(PAGE_SIZE_OFFSET_IN_FILE_HEADER)
    @file.read(PAGE_SIZE_LENGTH_IN_FILE_HEADER).unpack("n")[0] # n: unsigned short (16-bit) in network byte order (= big-endian)
  end

  def get_sqlite_schema
    traverser = TableBTreeTraverser.new(@file, page_size, SQLITE_SCHEMA_PAGE_NUMBER)

    sqlite_schema = Database::SqliteSchema.new
    sqlite_schema.cnt_tables = traverser.cnt_records
    sqlite_schema.tables = traverser.get_records(Database::SqliteSchema::TABLE_ATTRIBUTES, nil)
    sqlite_schema
  end

  def get_table_metadata(table_name)
    table_info = self.sqlite_schema.tables.find{|tbl| tbl.fetch(:name) == table_name}
    table_root_page_index = table_info.fetch(:rootpage)
    # table_info is like:
    #    "CREATE TABLE butterscotch (id integer primary key, grape text,coffee text,watermelon text,strawberry text,vanilla text)"
    columns_defs = table_info.fetch(:sql).split(Regexp.union(["(", ")"]))[1].split(",")
    column_names = columns_defs.map{|col_def| col_def.split()[0]}
    col_primary_index_key = columns_defs.select{|col_def| col_def.include? "integer primary key"}[0].split()[0]

    [table_info, table_root_page_index, column_names, col_primary_index_key]
  end
end
