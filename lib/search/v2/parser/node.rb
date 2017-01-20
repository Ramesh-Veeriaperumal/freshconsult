module Search
  module V2
    module Parser
    	class NodeVisitor
				def visit_operator(node)
					# redefine in the subclass
				end

				def visit_operand(node)
					# redefine in the subclass
				end
			end

			class Node
				include Enumerable

				attr_accessor :data, :left, :right

				def initialize(data, left = nil, right = nil)
					@data = data
					@left = left
					@right = right
				end

				def each(&block)
			    left.each(&block) if left
			    block.call(self)
			    right.each(&block) if right
			  end

				def type
					:node
				end

				def accept(visitor)
					# redefine in subclass
				end
			end

			# Node which holds the operators AND, OR ...
			class OperatorNode < Node
				def type
					:operator
				end

				def accept(visitor)
					visitor.visit_operator(self)
				end
			end

			# Node holds the conditions given by the user eg: priority = 2, checked = false
			class OperandNode < Node
				def type
					:operand
				end

				def accept(visitor)
					visitor.visit_operand(self)
				end

				def key
					@data.first[0]
				end

				def value
					@data.first[1]
				end
			end
    end
  end
end