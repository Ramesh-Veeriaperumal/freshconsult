class Search::HomeController < Search::SearchController

	before_filter :set_native_mobile, :only => :index

	SUGGEST_LOAD_OPTIONS  = {
		Helpdesk::Note => { :include => [ :notable ] },
		Helpdesk::Ticket => { :include => [{:flexifield => :flexifield_def}, :ticket_states] },
		Topic => { :include => [:forum] }, Solution::Article => {}, User => {}, Customer => {}
	}

	def suggest
		search(search_classes, { :load => SUGGEST_LOAD_OPTIONS, :size => 40, :preference => :_primary_first, :page => 1 })
		respond_to do |format|
			format.json do
				@result_json.merge!({
					:term => @search_key,
					:more_results_text => 
							( @total_pages > @current_page ? t('search.see_more_results', :term => h(@search_key)).html_safe : nil ),
					:no_results_text => (t('search.no_results_msg') if @total_results == 0)
				})
				render :json => @result_json
			end
		end
	end

	protected
		def search_classes
			to_ret = [] 
			respond_to do |format|
				format.html do
					to_ret = all_classes
				end
				format.nmobile do 
					if(params[:search_class].to_s.eql?("ticket"))
						to_ret = [ Helpdesk::Ticket ]
					elsif (params[:search_class].to_s.eql?("solutions"))
						to_ret = [ Solution::Article ] if privilege?(:view_solutions)
					elsif (params[:search_class].to_s.eql?("forums"))
						to_ret = [ Topic ] if privilege?(:view_forums)
					elsif (params[:search_class].to_s.eql?("customer"))
						if privilege?(:view_contacts)
							to_ret = [Customer] 
							to_ret << User
						end
					else
						to_ret = all_classes
					end
				end
				format.json do
					to_ret = all_classes
				end
				format.xml do 
					to_ret = all_classes
				end
			end
			to_ret
			# to_ret.map { |to_ret| to_ret = to_ret.document_type }
		end

		def initialize_search_parameters
			super
			if action_name == "suggest"
				@suggest = true
				@search_recursion_limit = 2
				@result_count_limit = 15
			end
		end
end