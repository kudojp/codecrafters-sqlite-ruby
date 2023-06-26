module Database
  class SqliteSchema
    TABLE_ATTRIBUTES = ["type", "name", "tbl_name", "rootpage", "sql"].freeze # attributes held for each table

    attr_accessor :cnt_tables
    attr_accessor :tables

    def initialize(tables)
      @tables = tables
    end

    def cnt_tables
      @tables.length
    end
  end
end
