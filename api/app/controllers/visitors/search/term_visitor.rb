module Search
	class TermVisitor < Search::V2::Parser::NodeVisitor
		include SearchHelper

		attr_accessor :column_names, :resource, :not_analyzed, :date_fields

		def initialize(column_names, date_fields)
			@column_names = column_names
			@date_fields = date_fields
			# Currently pre fetch is not required
			# @resource = resource
		end

		def visit_operator(node)
			bool_filter(reduce_level(node.data, node.left, node.right))
		end

		def reduce_level(data, left, right)
			if [data, left.type, right.type] == ['OR', :operand, :operand] && left.key == right.key && @date_fields.exclude?(left.key)
				{ ApiSearchConstants::ES_OPERATORS[data] => [ terms_filter(construct_key(left), [left.value, right.value]) ] }
			else
				{ ApiSearchConstants::ES_OPERATORS[data] => [left.accept(self), right.accept(self)] }
			end
		end
		
		def visit_operand(node)
			# Currently no such attribute is supported. If ticket search supports 'email' then uncomment the lines
			# if ApiSearchConstants::PRE_FETCH[@resource] && ApiSearchConstants::PRE_FETCH[@resource].keys.include?(node.key)
			# 	search_term = { terms: { construct_key(node) => [node.value] } }
			# 	contact_ids = ids_from_esv2_response(query_es(search_term, :contacts))
			# 	value = contact_ids.any? ? contact_ids[0] : 0
			# 	node.data = { ApiSearchConstants::PRE_FETCH[@resource][node.key] => value }				
			# end
			# If we filter for 'false' value for boolean we need to include records with 'nil' too
			key = construct_key(node)
			if key =~ /^ff_boolean/ && node.value == 'false'
				bool_filter({
					must: [
						bool_filter({
							should: [
								term_filter(@column_names[node.key], false),
								not_exists_filter(@column_names[node.key])
							]
						})
					]
				})
			elsif ["<", ">"].include?(node.action)
				value = (node.action == "<") ? end_of_day(node.value) : beginning_of_day(node.value)
				bool_filter(
					range_filter({ 
						key => {
							ApiSearchConstants::ES_OPERATORS[node.action] => value
						}
					})
				)
			elsif @date_fields.include?(key)
				bool_filter(
					range_filter({ 
						key => on_a_date(node.value)
					})
				)
			else
				terms_filter(key,[node.value])
			end
		end

		def construct_key(node)
			key = (@column_names[node.key] || ApiSearchConstants::ES_KEYS[node.key] || node.key)
			key = "#{key}.not_analyzed" if  not_analyzed.include?(key)
			key
		end

		def not_analyzed
			@not_analyzed ||= Flexifield.column_names.select{|x| x if x =~ /^ffs/} + ["tag_names"]
		end

		def term_filter(field_name, value)
			{ term: { field_name => value } }
		end

		def terms_filter(field_name, array)
			{ terms: { field_name => array } }
		end

		def not_exists_filter(field_name)
			{ not: { exists: { field: field_name } } }
		end

		def bool_filter(cond_block)
      { bool: cond_block }
    end

    def range_filter(cond_block)
    	{ filter: { range: cond_block } }
		end

		def on_a_date(value)
			{ "gte" => beginning_of_day(value), "lte" => end_of_day(value) }
		end

		def beginning_of_day(value)
			Time.zone.parse(value).beginning_of_day.utc.iso8601
		end

		def end_of_day(value)
			Time.zone.parse(value).end_of_day.utc.iso8601
		end
	end
end
