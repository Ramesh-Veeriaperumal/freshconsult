#encoding: utf-8

# Workaround for Wildcard search for LONG type
module Search::ESDisplayIdWildcardSearch

	def wilcard_range_queries
		search_key = SearchUtil.es_filter_key(@search_key, false).to_i
		max_display_id = current_account.get_max_display_id

		#Hack for fetching zero results when search_key is not a number
		return ([{ :term => { :display_id => 0 }}]) if search_key.zero?

		return [] if (search_key > max_display_id)
		wildcard_ranges(search_key, max_display_id)
	end

	def wildcard_ranges search_key, max_disp_id
		size = (max_disp_id.to_s.size - 1)
		max = get_wildcard_limit(search_key, max_disp_id, size)

		range_queries = [{ :term => { :display_id => search_key } }]
		(1..size-1).each do |pow|
			range_queries << range_expression((search_key*(10**pow)), ((search_key+1)*(10**pow)-1))
		end
		range_queries << range_expression((search_key*(10**size)), max)
		range_queries
	end

	def get_wildcard_limit search_key, max_disp_id, size
		limit = (search_key+1) * (10 ** size) - 1
		(limit < max_disp_id) ? limit : max_disp_id
	end

	def range_expression low_limit, up_limit
		({ :numeric_range => { :display_id => { :gte => low_limit, :lt => up_limit } } })
	end

end