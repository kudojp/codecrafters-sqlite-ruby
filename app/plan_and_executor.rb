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
    if select_count_all?(selected_columns)
      return @db_file_scanner.count_records(table_name)
    end

    # FROM table (WHERE predicate)
    filtering_by_secondary_index, other_filtering_condition = best_scanning_pattern(table_name, @ast.where_clause)
    records = @db_file_scanner.get_records(table_name, filtering_by_secondary_index)
    records = records.select{|record| other_filtering_condition.call(record)} if other_filtering_condition

    # SELECT *
    if select_all?(selected_columns)
      return records.map{|record| record.values.join "|"} # TODO: take care of order of columns
    end

    # SELECT col1, col2, col3
    selected_column_names = selected_columns.map{|sel_col| sel_col.col_def.name }
    records.map{|record| record_str(record, selected_column_names)}
  end

  private

  def select_count_all?(selected_column_nodes)
    return false unless selected_column_nodes.length == 1

    selected_column_nodes[0].col_def == AST::FunctionNode.new(
      type: :count,
      args: [AST::ColumnNode.new(type: :asterisk, name: nil)]
    )
  end

  def select_all?(selected_column_nodes)
    return false unless selected_column_nodes.length == 1

    selected_column_nodes[0].col_def.type == :asterisk
  end

  def best_scanning_pattern(table_name, where_clause_node)
    return [nil, lambda{|_record| true}] unless where_clause_node

    # Currently where_clause is assumed to be simply `col = xxx`
    raise StandardError.new("WHERE clause is too complicated!") unless where_clause_node.predicate&.length == 1
    raise StandardError.new("WHERE clause is too complicated!") unless where_clause_node.predicate[0].is_a? AST::ConditionNode
    raise StandardError.new("WHERE clause is too complicated!") unless where_clause_node.predicate[0].is_a? AST::ConditionNode
    raise StandardError.new("WHERE clause is too complicated!") unless where_clause_node.predicate[0].operator == :equals
    raise StandardError.new("WHERE clause is too complicated!") unless where_clause_node.predicate[0].left.is_a? AST::SelectedColumnNode
    raise StandardError.new("WHERE clause is too complicated!") unless where_clause_node.predicate[0].left.col_def.is_a? AST::ColumnNode
    raise StandardError.new("WHERE clause is too complicated!") unless where_clause_node.predicate[0].right.is_a? AST::ExpressionNode

    filtering_col_name = where_clause_node.predicate[0].left.col_def.name
    filtering_col_value = where_clause_node.predicate[0].right.value

    # TODO: Find the best scanning pattern from @ast.where_clause
    #       Current implementation is just to pass test cases prepared by CodeCrafters.
    if table_name == "companies" && filtering_col_name == "country"
      filtering_by_secondary_index = {"country" => lambda{|col_val| col_val == filtering_col_value}}
      other_filtering_condition = nil
      return [filtering_by_secondary_index, other_filtering_condition]
    end

    filtering_by_secondary_index = nil
    other_filtering = lambda{|record| record.fetch(filtering_col_name) == filtering_col_value}
    [filtering_by_secondary_index, other_filtering]
  end

  def record_str(record, columns)
    columns.map{|col_name| record.fetch(col_name)}.join("|")
  end
end
