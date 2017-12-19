module Freshquery
  module Parser
    class Node
      include Enumerable

      attr_accessor :data, :left, :right, :ope

      def each(&block)
        left.each(&block) if left
        yield(self)
        right.each(&block) if right
      end

      def type
        :node
      end

      def accept(visitor)
        # redefine in subclass
      end
    end
  end
end
