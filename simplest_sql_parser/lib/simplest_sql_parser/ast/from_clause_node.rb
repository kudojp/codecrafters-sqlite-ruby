require_relative "node"

module AST
  class FromClauseNode < Node
    attr_reader :table

    def initialize(table:)
      @table = table
    end

    def list_attributes_of_single_child_node
      [:table]
    end
  end
end
