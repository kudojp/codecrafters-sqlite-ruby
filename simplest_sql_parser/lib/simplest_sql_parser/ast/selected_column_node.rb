require_relative "node"

module AST
  class SelectedColumnNode < Node
    attr_reader :alias_name, :col_def

    def initialize(col_def:, alias_name: nil)
      @col_def = col_def
      @alias_name = alias_name
    end

    def list_attributes_without_child
      [:alias_name]
    end

    def list_attributes_of_single_child_node
      [:col_def]
    end
  end
end
