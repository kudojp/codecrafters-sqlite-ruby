require_relative "node"

module AST
  class SelectClauseNode < Node
    attr_reader :selected_columns

    def initialize(selected_columns:)
      @selected_columns = selected_columns # array of ColumnNode instances
    end

    def list_attributes_of_multiple_child_nodes
      [:selected_columns]
    end
  end
end
