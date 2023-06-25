class PlanAndExecutor
  def initialize(ast, db_file_scanner)
    @ast = ast
    @db_file_scanner = db_file_scanner
  end

  def execute
    # TODO: Fix me because this works when @ast is an actual query string.
    # Assuming that the @ast is "SELECT xxx FROM yyy;"
    matches = /(?i)select(?-i) (?<columns>.+) +(?i)from(?-i) +(?<table_name>\S+)/.match @ast
    columns = matches[:columns]
    table_name = matches[:table_name]

    if columns == "count(*)"
      return @db_file_scanner.count_records(table_name)
    end

    records = @db_file_scanner.get_records(table_name)

    # columns = `col, col2, col3`
    column_names = columns.split(",").map(&:strip)
    select_cols = lambda{|record| column_names.map{|col| record.fetch(col)}.join "|"}
    return records.map{|record| select_cols.call(record)}.join "\n"
  end
end
