require 'json'

class Search::SearchController < ApplicationController

	include Search::SearchResultJson
	
	before_filter :set_search_sort_cookie, :only => :index

	before_filter :initialize_search_parameters

	INCLUDE_ASSOCIATIONS_BY_CLASS = {
				Helpdesk::Note => { :include => [ :note_old_body, {:notable => [:ticket_status, :ticket_states, 
															:responder, :group, {:requester => :avatar} ] } ] },
				Helpdesk::Ticket => { :include => [{:flexifield => :flexifield_def}, {:requester => :avatar}, 
												:ticket_states, :ticket_old_body, :ticket_status, :responder, :group]},
				Topic => { :include => [ {:forum => :forum_category}, :user] },
				Solution::Article => { :include => [ :user, :folder ] },
				User => { :include => [:avatar, :customer]}, Customer => {}
			}

	def index
		(@search_key.blank? and params[:search_conditions].blank?) ? set_result_json : search(search_classes)
		post_process
	end

	# Search query
	def search(search_in = nil, options = { :load => INCLUDE_ASSOCIATIONS_BY_CLASS.slice(*search_in), 
							:size => 30, :preference => :_primary_first, :page => (params[:page] || 1).to_i })
		# The :load => true option will load the final results from database. It uses find_by_id internally.
		begin
			if privilege?(:manage_tickets)
				Search::EsIndexDefinition.es_cluster(current_account.id)
				items = Tire.search Search::EsIndexDefinition.searchable_aliases(search_in, current_account.id, @search_lang), options do |search|
					search.query do |query|
						query.filtered do |f|
							search_query f
							f.filter :term, { :account_id => current_account.id }
							search_filter_query(f, search_in)

							f.filter :bool, :must => keyword_search_filters if @keyword_search
						end
					end
					search_sort(search)
					search.from options[:size].to_i * (options[:page]-1)
					search_highlight search
				end
			end
			@result_set = items.results
			@total_pages = @result_set.total_pages
			@search_recursion_counter += 1
			process_results(search_in, options) unless is_native_mobile?
		rescue Exception => e
			set_result_json
			Rails.logger.debug e.inspect
			NewRelic::Agent.notice_error(e)
		end
	end

	protected

		def search_query f
			f.query do |q|
				q.boolean do |b|
					exact_or_wildcard_query(b)
					keyword_search_queries(b) if @keyword_search
				end
			end
		end

		def exact_or_wildcard_query b_query
			if SearchUtil.es_exact_match?(@search_key)
				query = SearchUtil.es_filter_exact(@search_key) #Initializing into a variable as inaccessible inside block
				
				#_Note_: Text query deprecated and renamed to match query.
				b_query.must { match :_all, query, :type => :phrase }
			else
				query = SearchUtil.es_filter_key(@search_key, !@search_lang.present?) #Initializing into a variable as inaccessible inside block
				analyzer = SearchUtil.analyzer(@search_lang) #Initializing into a variable as inaccessible inside block
				b_query.must { string query, :analyzer => analyzer }
			end
		end

		def search_filter_query f, search_in         
			f.filter :or, { :not => { :exists => { :field => :deleted } } },
															{ :term => { :deleted => false } }
			f.filter :or, { :not => { :exists => { :field => :spam } } },
										{ :term => { :spam => false } }
			f.filter :or, { :not => { :exists => { :field => :helpdesk_agent } } },
										{ :term => { :helpdesk_agent => false } }
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
			unless search_in.blank?
				if search_in.include?(Solution::Article)
					f.filter :term,  { 'folder.category_id' => params[:category_id] } if params[:category_id]
					f.filter :or, { :not => { :exists => { :field => :language_id } } },
											{ :term => { :language_id => Language.for_current_account.id } }
				end
				f.filter :term,  { 'forum.forum_category_id' => params[:category_id] } if 
																		params[:category_id] && search_in.include?(Topic)
			end
		end

		def search_sort search
			search.sort { |t| t.by(@search_sort,'desc') } if (@search_sort and (@search_sort != 'relevance') and !@suggest)
		end

		def search_highlight search
			search.highlight :desc_un_html, :title, :description, :subject, :job_title, :name, :options => highlight_options
		end

		def highlight_options
			{ :tag => '<span>', :fragment_size => 80, :number_of_fragments => 4, :encoder => 'html' }
		end

		def process_results search_in, options
			@result_set.each_with_hit do |result,hit|
				next if([Helpdesk::Ticket, Helpdesk::Note,Helpdesk::ArchiveTicket,Helpdesk::ArchiveNote].include?(result.class) and result_discarded?(result))
				@results[result.class.name] ||= []
				result = SearchUtil.highlight_results(result, hit) unless hit['highlight'].blank?
				@results[result.class.name] << result
				@result_json[:results] << send(%{#{result.class.model_name.singular}_json}, result) if result
			end

			@search_results = (@search_results.presence || []) + @result_set.results
			
			@total_results = @search_results.size

			if ((@search_recursion_counter < @search_recursion_limit) && (@total_results < @result_count_limit) && 
														(options[:page] < @total_pages) && !@search_by_field)
				options[:page] += 1
				search(search_in, options) 	
			else
				@current_page = options[:page]
				search_key_value = (params[:term] || params[:q] || params[:search_key])
				@search_key = search_key_value.gsub(/\\/,'') unless search_key_value.nil?
				generate_result_json unless @suggest
			end

			rescue Exception => e
				set_result_json
				Rails.logger.debug e.inspect
				NewRelic::Agent.notice_error(e)
		end

		def result_discarded? result
			if(result.class == Helpdesk::Ticket) 
			  parent_ticket_id = result.id
			elsif(result.class == Helpdesk::ArchiveTicket)
			  parent_ticket_id = result.ticket_id	
			elsif(result.class == Helpdesk::ArchiveNote)
			  parent_ticket_id =  result.notable_id
			else
			  parent_ticket_id = result.notable_id	
			end
			if @searched_ticket_ids.include?(parent_ticket_id)
				@result_set.results.delete(result) and return true
			end
			@searched_ticket_ids << parent_ticket_id and return false
		end

		def generate_result_json
			@result_json[:current_page] = @current_page
			set_result_json
		end

		def post_process
			respond_to do |format|
				default_responses format
			end
		end

		def default_responses format
			format.html do 
				if request.xhr? and !request.headers['X-PJAX']
					render :partial => '/search/result'
				else
					render 'search/index'
				end
			end
			format.js do 
				render :partial => 'search/search_sort'
			end
			format.json do
				render :json => @result_json
			end
      format.nmobile do
        array = []
        @result_set.each do |item|
          next if item.is_a?(Helpdesk::ArchiveTicket)
          array << item.to_mob_json_search
        end
        render :json => array
      end
			unless ["forums", "solutions"].include?(controller_name)
				format.xml do
					render_404
				end
			end
		end

		def all_classes
			classes = [ Helpdesk::Ticket ]
			classes << Helpdesk::Note unless current_user.restricted? or is_native_mobile?
			classes << Solution::Article if privilege?(:view_solutions) 
			classes << Topic             if privilege?(:view_forums)
			if privilege?(:view_contacts)
				classes << User
				classes << Customer
			end
			classes
		end

		def initialize_search_parameters
			@search_key = params[:term] || params[:search_key] || ''
			initialize_search_sort
			@result_json = { :results => [], :current_page => 1 }
			@search_recursion_limit = 4
			@search_recursion_counter = 0
			@result_count_limit = 30
			@results = {}
			@searched_ticket_ids = []
			@keyword_search = respond_to?(:keyword_search_filters) and respond_to?(:keyword_search_queries) # Can be removed if its implemented for all
		end

		def initialize_search_sort
			@search_sort = params[:search_sort] || (cookies[:search_sort] || 
												(controller_name == "tickets" ? 'created_at' : @search_sort))
		end

		def set_search_sort_cookie
			cookies[:search_sort] = params[:search_sort] if params[:search_sort]
		end

		def set_result_json
			@result_json = @result_json.to_json
		end
end