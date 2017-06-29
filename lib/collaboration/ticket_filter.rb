module Collaboration::TicketFilter
	def collab_filter_enabled_for?(filter_name)
		@collab_filters = Collaboration::Ticket::FILTER_LIST
		Account.current.collaboration_enabled? && @collab_filters.select {|cfilter| cfilter == filter_name}.any?
	end

	def collab_filter_with_group_collab_for?(filter_name)
		Account.current.group_collab_enabled? &&
			collab_filter_enabled_for?(filter_name)
	end
end