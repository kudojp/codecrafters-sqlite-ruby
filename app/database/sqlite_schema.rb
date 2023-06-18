module Database
  class SqliteSchema
    TABLE_ATTRIBUTES = [:type, :name, :tbl_name, :rootpage, :sql] # attributes held for each table

    attr_accessor :cnt_tables
    attr_accessor :tables
  end
end
