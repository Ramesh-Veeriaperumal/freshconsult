class Search::TicketsController < Search::SearchController

	include Search::ESDisplayIdWildcardSearch

	before_filter :set_native_mobile, :only => [:index]

	TICKET_SEARCH_FIELDS = ["display_id", "subject", "requester"]


	def index
		if @search_by_field
			search([Helpdesk::Ticket], { :size => 1000, 
					:load => { Helpdesk::Ticket => { :include => [:requester, :ticket_states, {:flexifield => :flexifield_def}] }},
					:preference => :_primary_first, :page => 1}) if TICKET_SEARCH_FIELDS.include?(params[:search_field])
			respond_to do |format|
				format.any(:json, :nmobile) { render :json => @result_json }
			end
		else
			super
		end
  	end
    
	protected

		def search_with_requester
			users = User.search_by_name(@search_key, current_account.id,
										{:page => 1, :size => 1000, :preference => :_primary_first })
			@requester_ids = users.blank? ? [] : users.results.map(&:id)
		end

		def search_classes
			search_classes = [ Helpdesk::Ticket ]
			search_classes << Helpdesk::Note unless current_user.restricted? or is_native_mobile?
			search_classes
		end

		def search_query f
			if @search_by_field
				if SearchUtil.es_exact_match?(@search_key) and (params[:search_field] != "requester")
					f.query { |q| q.text params[:search_field].to_sym, SearchUtil.es_filter_exact(@search_key), :type => :phrase }				
				else
					case params[:search_field]
					when "display_id"
						f.filter :bool, :should => wilcard_range_queries
						# f.filter :script, { 
						# :script => 
						# 	"doc['display_id'].value.toString() ~= '^#{SearchUtil.es_filter_key(@search_key, false)}[0-9]*$'"
						# }
					when "subject"
						f.query { |q| q.string SearchUtil.es_filter_key(@search_key), 
											:fields => [ 'subject' ], :analyzer => "include_stop" }
					when "requester"
						f.filter :terms, { :requester_id => @requester_ids }
					end
				end
			else
				super(f)
			end
		end

		def search_filter_query f, search_in         
			f.filter :or, { :not => { :exists => { :field => :deleted } } },
									{ :term => { :deleted => false } }
			f.filter :or, { :not => { :exists => { :field => :spam } } },
									{ :term => { :spam => false } }
			if current_user.restricted?
				user_groups = current_user.group_ticket_permission ? current_user.agent_groups.map(&:group_id) : []
				f.filter :or, { :not => { :exists => { :field => :responder_id } } },
											{ :term => { :responder_id => current_user.id } },
											{ :terms => { :group_id => user_groups } }
			else
				f.filter :or, { :not => { :exists => { :field => :notable_deleted } } },
											{ :term => { :notable_deleted => false } }
				f.filter :or, { :not => { :exists => { :field => :notable_spam } } },
											{ :term => { :notable_spam => false } }
			end
		end

		def search_sort search
			if @search_by_field and params[:search_field] == "display_id"
				search.sort { |t| t.by('display_id','asc') }
			else
				super(search)
			end
		end

		def search_highlight search
			search.highlight :description, :subject, :options => highlight_options
		end

		def initialize_search_parameters
			super
			if params.has_key?(:search_field)
				@search_sort = 'created_at'
				@search_by_field = true
				search_with_requester if params[:search_field] == "requester"
			end
		end
end