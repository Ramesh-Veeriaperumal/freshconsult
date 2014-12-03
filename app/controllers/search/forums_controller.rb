class Search::ForumsController < Search::SearchController

	protected
		def search_classes
			[Topic]
		end

		def search_filter_query f, search_in  
			unless search_in.blank?
				f.filter :term,  { 'forum.forum_category_id' => params[:category_id] } if params[:category_id]
			end
		end   

		def search_highlight search
			search.highlight :title, :options => highlight_options
		end

		def post_process
			respond_to do |format|
				default_responses format
				format.xml do
					api_xml = []
					api_xml = @search_results.to_xml
					render :xml => api_xml
				end
			end
		end

end