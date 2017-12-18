module Freshquery
  module Parser
    # Node which holds the operators AND, OR ...
    class OperatorNode < Node
      def initialize(data, left, right)
        @data = data
        @left = left
        @right = right
      end

      def type
        :operator
      end

      def accept(visitor)
        visitor.visit_operator(self)
      end
    end
  end
end
