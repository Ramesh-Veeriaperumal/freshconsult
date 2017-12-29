module Freshquery
  module Parser
    # Node holds the conditions given by the user eg: priority = 2, checked = false
    class OperandNode < Node
      def initialize(data, ope = ':')
        @data = data
        @ope = ope
      end

      def type
        :operand
      end

      def accept(visitor)
        visitor.visit_operand(self)
      end

      def key
        @data.first[0]
      end

      def action
        @ope
      end

      def value
        @data.first[1]
      end
    end
  end
end
