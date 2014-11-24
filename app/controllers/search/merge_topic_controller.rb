class Search::MergeTopicController < Search::ForumsController

	before_filter :set_params

	protected

		def set_params
			@search_sort = 'created_at'
			@search_by_field = true
		end

		def search_query f
			f.query { |q| q.string SearchUtil.es_filter_key(@search_key), :fields => [ 'title', 'posts.body' ], :analyzer => "include_stop" }
		end       

		def generate_result_json
			@result_json[:results].reject! { |t| t[:locked] === true }
			@result_json = @result_json.to_json
		end

		def topic_json topic
			json = super
			json[:created_at] = json[:created_at].to_i
			json
		end

end