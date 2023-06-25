class PlanAndExecutor
  def initialize(ast, db_file_scanner)
    @ast = ast
    @db_file_scanner = db_file_scanner
  end

  def execute
    selected_columns = @ast.select_clause.selected_columns
    from_table = @ast.from_clause.from_table
    table_name = from_table.table_def.name # This can parse only the simplest case.

    # SELECT count(*)
    if (selected_columns.length == 1) && (select_count_all? selected_columns[0])
      return @db_file_scanner.count_records(table_name)
    end

    records = @db_file_scanner.get_records(table_name)

    # SELECT col, col2, col3
    selected_column_names = selected_columns.map{|sel_col| sel_col.col_def.name }

    return records.map{|record| record_str(record, selected_column_names)}
  end

  private

  def select_count_all?(selected_column_node)
    selected_column_node.col_def == AST::FunctionNode.new(
      type: :count,
      args: [AST::ColumnNode.new(type: :asterisk, name: nil)]
    )
  end

  def record_str(record, columns)
    columns.map{|col_name| record[col_name]}.join("|")
  end
end
