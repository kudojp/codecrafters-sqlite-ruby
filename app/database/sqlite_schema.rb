module Database
  class SqliteSchema
    attr_accessor :cnt_tables

    def tables
      @tables ||= ["tbl_name1", "tbl_name2"]
    end
  end
end
