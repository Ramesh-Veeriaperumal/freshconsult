module Collaboration::TicketFilter
	def collab_filter_enabled_for?(filter_name)
		@collab_filters = Collaboration::Ticket.filter_list
		Account.current.collab_feature_enabled? && @collab_filters.select {|cfilter| cfilter == filter_name}.any?
	end
end