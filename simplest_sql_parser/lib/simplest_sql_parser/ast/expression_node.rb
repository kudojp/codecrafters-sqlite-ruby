require_relative "node"

module AST
  class ExpressionNode < Node
    attr_reader :value

    def initialize(value:)
      @value = value
    end

    def list_attributes_without_child
      [:value]
    end
  end
end
