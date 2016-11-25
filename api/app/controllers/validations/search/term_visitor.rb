module Search
	class TermVisitor < Search::V2::Parser::NodeVisitor
		include SearchHelper

		attr_accessor :column_names, :parser

		def initialize(column_names, parser)
			@column_names = column_names
			@parser = parser
		end

		def visit_operator(node)
			{
				bool: reduce_level(node.data, node.left, node.right)
			}
		end

		def reduce_level(data, left, right)
			if [data, left.type, right.type] == ['OR', :operand, :operand] && left.key == right.key
				{ operator(data) => [{ terms: { construct_key(left) => [left.value, right.value] } }] }
			else
				{ operator(data) => [left.accept(self), right.accept(self)] }
			end
		end

		def operator(data)
			data == 'OR' ? :should : :must
		end

		def visit_operand(node)
			if ApiSearchConstants::PRE_FETCH.keys.include?(node.key)
				search_term = { terms: { construct_key(node) => [node.value] } }
				contact_ids = ids_from_esv2_response(query_es(search_term, :contacts))
				value = contact_ids.any? ? contact_ids[0] : 0
				node.data = { ApiSearchConstants::PRE_FETCH[node.key] => value }				
			end
			{
				terms: {
					 construct_key(node) => [node.value] 
				}
			}
		end

		def construct_key(node)
			key = (@column_names[node.key] || ApiSearchConstants::ES_KEYS[node.key] || node.key)
			key = "#{key}.not_analyzed" if node.value.is_a?(String)
			key
		end
	end
end
