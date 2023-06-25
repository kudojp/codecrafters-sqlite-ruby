require_relative "node"

module AST
  class FromClauseNode < Node
    attr_reader :from_table

    def initialize(from_table:)
      @from_table = from_table
    end

    def list_attributes_of_single_child_node
      [:from_table]
    end
  end
end
