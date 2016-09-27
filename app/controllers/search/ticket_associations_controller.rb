class Search::TicketAssociationsController < Search::TicketsController

	before_filter :set_native_mobile, :initialize_search_parameters, :only => [:index]

	def index
		search([Helpdesk::Ticket], { :size => 30, 
			:load => { Helpdesk::Ticket => { :include => [:requester, :ticket_status] }},
			:preference => :_primary_first, :page => 1, :without_archive => true})
		respond_to do |format|
			format.json { render :json => @result_json }
			format.nmobile {
				array = [] 
				@result_set.each { |item|
				array << item.to_mob_json_merge_search
				}
				render :json => array
			}
		end
	end

	protected

		def search_filter_query f, search_in
			f.filter :or, { :not => { :exists => { :field => :deleted } } },
				{ :term => { :deleted => false } }
			f.filter :or, { :not => { :exists => { :field => :spam } } },
				{ :term => { :spam => false } }
			f.filter :term, { :association_type => TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:tracker] }
			f.filter :not,  { :filter => { :terms => {:status => [Helpdesk::Ticketfields::TicketStatus::CLOSED, Helpdesk::Ticketfields::TicketStatus::RESOLVED]} } } if @recent_trackers
		end

		def initialize_search_parameters
			super
			@recent_trackers =  !TICKET_SEARCH_FIELDS.include?(params[:search_field])
			@search_by_field = TICKET_SEARCH_FIELDS.include?(params[:search_field])
			@search_sort = 'created_at'
		end
end