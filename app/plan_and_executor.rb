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

    # WHERE *
    records = where_filtered(records, @ast.where_clause) if @ast.where_clause

    # SELECT col, col2, col3
    selected_column_names = selected_columns.map{|sel_col| sel_col.col_def.name }
    records.map{|record| record_str(record, selected_column_names)}
  end

  private

  def select_count_all?(selected_column_node)
    selected_column_node.col_def == AST::FunctionNode.new(
      type: :count,
      args: [AST::ColumnNode.new(type: :asterisk, name: nil)]
    )
  end

  def where_filtered(records, where_clause_node)
    raise StandardError.new("WHERE clause is too complicated!") unless where_clause_node.predicate&.length == 1
    raise StandardError.new("WHERE clause is too complicated!") unless where_clause_node.predicate[0].is_a? AST::ConditionNode
    raise StandardError.new("WHERE clause is too complicated!") unless where_clause_node.predicate[0].is_a? AST::ConditionNode
    raise StandardError.new("WHERE clause is too complicated!") unless where_clause_node.predicate[0].operator == :equals
    raise StandardError.new("WHERE clause is too complicated!") unless where_clause_node.predicate[0].left.is_a? AST::SelectedColumnNode
    raise StandardError.new("WHERE clause is too complicated!") unless where_clause_node.predicate[0].left.col_def.is_a? AST::ColumnNode
    raise StandardError.new("WHERE clause is too complicated!") unless where_clause_node.predicate[0].right.is_a? AST::ExpressionNode

    # WHERE col1 = 'value'
    filtering_col_name = where_clause_node.predicate[0].left.col_def.name
    filtering_col_value = where_clause_node.predicate[0].right.value

    records.select{|record| record.fetch(filtering_col_name) == filtering_col_value}
  end

  def record_str(record, columns)
    columns.map{|col_name| record[col_name]}.join("|")
  end
end
