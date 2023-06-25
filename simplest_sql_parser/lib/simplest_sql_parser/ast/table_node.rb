require_relative "node"

module AST
  class TableNode < Node
    attr_reader :name

    def initialize(name:)
      @name = name
    end

    def list_attributes_without_child
      [:name]
    end
  end
end
