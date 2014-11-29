class Search::MergeTopicController < Search::ForumsController

	before_filter :set_params

	protected

		def set_params
			@search_sort = 'created_at'
			@search_by_field = true
		end


		def search_filter_query f, search_in  
			unless search_in.blank?
				f.filter :term,  { 'forum.forum_category_id' => params[:category_id] } if params[:category_id]
			end
			f.filter :term,  { 'forum.forum_visibility' => params[:forum_visibility] } if params[:forum_visibility]
		end

		def generate_result_json
			@result_json[:results].reject! { |t| t[:locked] == true }
			@result_json = @result_json.to_json
		end

		def topic_json topic
			json = super
			json[:created_at] = json[:created_at].to_i
			json
		end

end