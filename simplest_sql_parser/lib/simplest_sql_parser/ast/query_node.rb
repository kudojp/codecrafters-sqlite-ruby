require_relative "node"

module AST
  class QueryNode < Node
    attr_reader :select_clause, :from_clause, :where_clause

    def initialize(select_clause: nil, from_clause: nil, where_clause: nil)
      @select_clause = select_clause
      @from_clause = from_clause
      @where_clause = where_clause
    end

    def list_attributes_of_single_child_node
      [:select_clause, :from_clause, :where_clause]
    end
  end
end
