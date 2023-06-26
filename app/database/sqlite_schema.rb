module Database
  class SqliteSchema
    TABLE_ATTRIBUTES = ["type", "name", "tbl_name", "rootpage", "sql"].freeze # attributes held for each table

    attr_accessor :records

    def initialize(records)
      @records = records
    end

    def tables
      @records.select{|rec| rec.fetch("type") == "table"}
    end

    def indexes
      @records.select{|rec| rec.fetch("type") == "index"}
    end

    def applicable_index(table, column)
      @records.find{|rec|
        rec.fetch("type") == "index" &&
        rec.fetch("name") == "idx_#{table}_#{column}" &&
        rec.fetch("table_name") == table
      }
    end
  end
end
