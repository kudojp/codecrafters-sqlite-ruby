module AST
  class Node # used as an abstract class
    # This should be overwritten in each node if necessary.
    def list_attributes_without_child
      []
      # ["attr1", "attr2"]
    end

    # This should be overwritten in each node if necessary.
    def list_attributes_of_single_child_node
      []
      # [:attr3, attr4]
    end

    # This should be overwritten in each node if necessary.
    def list_attributes_of_multiple_child_nodes
      []
      # [:attr5, attr6]
    end

    def attributes
      list_attributes_without_child + list_attributes_of_single_child_node + list_attributes_of_multiple_child_nodes
    end

    # Overwritten for rspec.
    # In rspec, `eq` matcher uses #==() to compare two objects.
    # In our case, when comparing two nodes, we must compare their descendant nodes as well.
    def ==(another_node)
      return false unless self.class == another_node.class

      self.attributes.each do |attr_sym|
        return false unless self.send(attr_sym) == another_node.send(attr_sym)
      end

      true
    end

    # Used only for debugging.
    def self_and_descendants
      attributes = list_attributes_without_child.map { |attr_sym| "#{attr_sym}=#{send(attr_sym)}" }.join ","

      descendants = {}

      list_attributes_of_single_child_node.each do |attr_sym|
        descendants[attr_sym.to_s] = send(attr_sym)&.self_and_descendants
      end

      list_attributes_of_multiple_child_nodes.each do |attr_sym|
        descendants[attr_sym.to_s] = send(attr_sym)&.map { |attribute| attribute.self_and_descendants }
      end

      { "#{self.class}(#{attributes})" => descendants }
    end
  end
end

=begin
QueryNode.new
  @select: SelectClauseNode.new
    @columns: Array.new
      - SelectedColumnNode.new   # name
          @alias_name: String.new
          @col_def: ColumnNode.new
            @type: :single_col
            @name: "name"
      - SelectedColumnNode.new   # *
          @alias_name: String.new
          @col_def: ColumnNode.new
            @type: :asterisk
            @name: nil
      - SelectedColumnNode.new   # COUNT(name)
          @alias_name: String.new
          @col_def: FunctionNode.new
            @type: :count
            @args: Array.new
              - ColumnNode.new
                @type: :single_col
                @name: "name"
  @from: FromClauseNode.new
    @from_table: FromTable.new       # or this could be FunctionNode of table/
      @alias_name: String.new
      @table_def: TableNode.new
        @name: String.new
 @where: WhereClauseNode.new
    @predicate: Array.new
      - ConditionNode.new
          @operator: :equals
          @left: ExpressionNode.new
          @right: ExpressionNode.new
      - EqualsConditionNode.new
          @operator: :larger_than
          @left: ExpressionNode.new
          @right: ExpressionNode.new

Maybe,,
- I should create separate classes for each ExpressionNode depending on where it is used??
- I should create a parent class `ClauseNode` for SelectClauseNode, FromClauseNode, and WhereClauseNode.
=end
