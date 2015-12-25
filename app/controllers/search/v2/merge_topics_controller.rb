# Topic Specific searches
#
class Search::V2::MergeTopicsController < Search::V2::SpotlightController

  def search_topics
    @searchable_klasses = ['Topic']
    search
  end
  
  private
  
    def construct_es_params
      params = super
      params[:topic_locked]     = 'false'
      params[:topic_visibility] = params[:forum_visibility].to_i if params[:forum_visibility]
      params
    end
    
    # Overriding to mimic merge_topic controller
    #
    def topic_json topic
			json = super
			json[:created_at] = json[:created_at].to_i
			json
		end
  
    def initialize_search_parameters
      super
      @search_context   = :merge_topic_search
      @search_by_field  = true
      @sort_by          = 'created_at'
    end

end