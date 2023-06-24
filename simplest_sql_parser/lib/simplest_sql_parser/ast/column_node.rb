require_relative "node"

module AST
  class ColumnNode < Node
    class UnsupportedTypeError < StandardError; end

    TYPES = [:single_col, :asterisk].freeze
    attr_reader :type, :name

    def initialize(name:, type: :single_col)
      raise UnsupportedTypeError unless TYPES.include? type

      @type = type # single_col
      @name = name # nil when type == :asterisk
    end

    def list_attributes_without_child
      [:type, :name]
    end
  end
end
