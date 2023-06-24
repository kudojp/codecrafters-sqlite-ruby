require_relative "node"

module AST
  class ConditionNode < Node
    class UnsupportedOperatorError < StandardError; end

    OPERATORS = [:equals, :larger_than].freeze # TODO: add more operators

    attr_reader :operator, :left, :right

    def initialize(operator:, left:, right:)
      raise UnsupportedOperatorError unless OPERATORS.include? operator

      @operator = operator
      @left = left
      @right = right
    end

    def list_attributes_without_child
      [:operator]
    end

    def list_attributes_of_single_child_node
      [:left, :right]
    end
  end
end
