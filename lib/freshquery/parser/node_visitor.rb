module Freshquery
  module Parser
    class NodeVisitor
      def visit_operator(node)
        # redefine in the subclass
      end

      def visit_operand(node)
        # redefine in the subclass
      end
    end
  end
end
