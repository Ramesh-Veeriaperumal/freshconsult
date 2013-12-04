class Freshfone::Filters::CallFilter < Wf::Filter
	ALLOWED_ORDERING = [ 'created_at', 'call_duration', 'cost' ]
	def results
		@results ||= begin
			handle_empty_filter! 
			recs = model_class.paginate(
				:order => order_clause,
				:page => page, :per_page => per_page,
				:conditions => sql_conditions,
				:joins => joins,
				:include => [:ticket, :note, :agent => [:avatar], :customer => [:avatar]] )
			recs.wf_filter = self
			recs
		end
	end

	def deserialize_from_params_with_validation(params)
		params["wf_order"] = nil unless ALLOWED_ORDERING.include?(params["wf_order"])
		deserialize_from_params_without_validation(params)
	end

	def default_order
		'created_at'
	end

	alias_method_chain :deserialize_from_params, :validation
end