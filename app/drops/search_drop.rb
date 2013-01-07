class SearchDrop < BaseDrop
  	include ActionController::UrlWriter

	def initialize(source)
		super source
	end

	def term
		@source[:term]
	end

	def result_count
		@source[:search_results].size
	end

	def results
		@source[:search_results]
	end

	def current_filter
		@source[:current_filter]
	end

	def pagination
		@source[:pagination]
	end

	def filters
		def_list = []

		def_list.push({ :name => :solutions,
	    			 	:url => solutions_support_search_path(:term => term) }) if
				( allowed_in_portal? :open_solutions )

		def_list.push({ :name => :topics,
	    			 		:url => topics_support_search_path(:term => term) }) if
				( allowed_in_portal? :open_forums )			

		if(User.current)
			def_list.push({ :name => :tickets,
	    			  		:url => tickets_support_search_path(:term => term) })
        end

        if(def_list.size > 1)
			def_list.unshift({ :name => :all, 
		    			  	:url => support_search_path(:term => term) })

			def_list
		else
			[]
		end		
	end

end