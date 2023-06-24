require_relative "node"

module AST
  class FunctionNode < Node
    class UnsupportedTypeError; end

    TYPES = [:count] # TODO: add other types (:max, etc)
    attr_reader :type, :args

    def initialize(type:, args: [])
      raise UnsupportedTypeError unless TYPES.include? type

      @type = type
      @args = args
    end

    def list_attributes_without_child
      [:type]
    end

    def list_attributes_of_multiple_child_nodes
      [:args]
    end
  end
end
