require_relative "node"

module AST
  class WhereClauseNode < Node
    attr_reader :predicate

    def initialize(predicate:)
      @predicate = predicate # array of ConditionNode instances
    end

    def list_attributes_of_multiple_child_nodes
      [:predicate]
    end
  end
end
