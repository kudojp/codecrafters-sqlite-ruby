require_relative "node"

module AST
  class FromTableNode < Node
    attr_reader :table_def, :alias_name

    def initialize(table_def:, alias_name: nil)
      @table_def = table_def
      @alias_name = alias_name
    end

    def list_attributes_without_child
      [:alias_name]
    end

    def list_attributes_of_single_child_node
      [:table_def]
    end
  end
end
