class Search::SolutionsController < Search::SearchController

	before_filter :load_ticket, :only => [:related_solutions, :search_solutions]

	def related_solutions
		article_suggest @ticket.subject
		article_suggest @ticket.description if @result_set.blank?
		respond_to do |format|
			format.js do
				render :layout => false
			end
      format.json do
        array = []
        @result_set.each do |article| 
          array <<  article.to_mob_json['article']
        end
        render :json => array
      end
    end
  end

	def search_solutions
		article_suggest params[:q]
		render :layout => false
	end

	protected

		def article_suggest search_by
			@search_key = search_by
			search(search_classes, {:load => INCLUDE_ASSOCIATIONS_BY_CLASS.slice(*search_classes), 
							:size => 30, :preference => :_primary_first, :page => 1})
		end

		def search_classes
			[Solution::Article]
		end

		def search_filter_query f, search_in         
			unless search_in.blank?
				f.filter :term,  { 'folder.category_id' => params[:category_id] } if params[:category_id]
				f.filter :term,  { 'folder_id' => params[:folder_id] } if params[:folder_id]
			end
		end

		def search_highlight search
			search.highlight :desc_un_html, :title, :options => highlight_options
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

		def initialize_search_parameters
			super
			if ["search_solutions", "related_solutions"].include?(action_name)
				@suggest = true
			end
			detect_multilingual_search
		end

		def load_ticket
			@ticket = current_account.tickets.find_by_id(params[:ticket])
			@ticket = current_account.tickets.find_by_display_id(params[:ticket]) if is_native_mobile?
		end

		# Hack for getting language and hitting corresponding alias
		# Probably will be moved to search/search_controller when dynamic solutions goes live
		def detect_multilingual_search
			if params[:language].present? and current_account.features_included?(:es_multilang_solutions)
				@search_lang = ({ :language => params[:language] })
			end
		end
end