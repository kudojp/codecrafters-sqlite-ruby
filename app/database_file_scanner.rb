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

  def get_records(table_name, secondary_index=nil)
    return get_records_by_index_scan(table_name, secondary_index) if secondary_index
    get_records_by_full_scan(table_name)
  end

  def get_records_by_full_scan(table_name)
    table_metadata = table_name_to_metadata(table_name)

    TableBTreeTraverser.new(
      @file,
      self.page_size,
      table_metadata.fetch(:root_page_index)
    ).get_records(
      table_metadata.fetch(:column_names),
      table_metadata.fetch(:col_primary_index_key)
    )
  end

  def get_records_by_index_scan(table_name, filtering_by_secondary_index)
    #TODO
    []
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

  def table_name_to_metadata(table_name)
    return @table_metadata[table_name] if @table_metadata&.key? table_name
    table_info = self.sqlite_schema.tables.find{|tbl| tbl.fetch(:name) == table_name}
    table_root_page_index = table_info.fetch(:rootpage)
    # table_info is like:
    #    "CREATE TABLE butterscotch (id integer primary key, grape text,coffee text,watermelon text,strawberry text,vanilla text)"
    columns_defs = table_info.fetch(:sql).split(Regexp.union(["(", ")"]))[1].split(",")
    column_names = columns_defs.map{|col_def| col_def.split()[0]}
    pk_columns_def = columns_defs.find{|col_def| col_def.include? "integer primary key"}
    col_primary_index_key = pk_columns_def ? pk_columns_def.split()[0] : nil

    @table_metadata = {}
    @table_metadata[:table_name] = {
      root_page_index: table_root_page_index,
      column_names: column_names,
      col_primary_index_key: col_primary_index_key
    }
  end
end
