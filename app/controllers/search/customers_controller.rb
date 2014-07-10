class Search::CustomersController < Search::SearchController

	protected
		def search_classes
			[Customer, User]
		end

		def search_filter_query f, search_in         
			f.filter :or, { :not => { :exists => { :field => :deleted } } },
										{ :term => { :deleted => false } }
			f.filter :or, { :not => { :exists => { :field => :helpdesk_agent } } },
										{ :term => { :helpdesk_agent => false } }
		end

		def search_highlight search
			search.highlight :description, :job_title, :name, :note, :options => highlight_options
		end
end