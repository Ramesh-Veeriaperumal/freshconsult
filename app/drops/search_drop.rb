class SearchDrop < BaseDrop
  	include Rails.application.routes.url_helpers

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
		def_list = [
			[:solutions, solutions_support_search_path(:term => term), @portal.has_solutions],
			[:topics, topics_support_search_path(:term => term), @portal.has_forums],
			[:tickets, tickets_support_search_path(:term => term), @portal.has_user_signed_in]
		].map{ |t| {:name => t[0], :url => t[1]} if(t[2]) }.compact

		(def_list.size > 1) ?
			def_list.unshift({  :name => :all, 
		    			  		:url => h(support_search_path(:term => term)) }) : []
	end

end