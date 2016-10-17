# Topic Specific searches
#
class Search::V2::MergeTopicsController < ApplicationController

  include Search::SearchResultJson
  include Search::V2::AbstractController

  def search_topics
    search(esv2_agent_models)
  end
  
  private
    
    def construct_es_params
      super.tap do |es_params|
        es_params[:topic_category_id] = params[:category_id].to_i if params[:category_id].present?
        es_params[:topic_visibility]  = params[:forum_visibility].to_i if params[:forum_visibility]
        es_params[:sort_by]           = @search_sort
        es_params[:sort_direction]    = @sort_direction
        es_params[:size]              = @size
        es_params[:from]              = @offset
      end
    end

    def process_results
      @result_set.each do |result|
        @result_json[:results] << send(%{#{result.class.model_name.singular}_json}, result) if result
      end
      super
    end

    def handle_rendering
      respond_to do |format|
        format.json do
          render :json => @result_json.to_json
        end
      end
    end
    
    # Overriding to mimic merge_topic controller
    #
    def topic_json topic
			super.tap do |json|
  			json[:created_at] = json[:created_at].to_i
			end
		end
  
    def initialize_search_parameters
      super
      @klasses          = ['Topic']
      @search_context   = :merge_topic_search
      @search_by_field  = true #=> Used in search_result_json.
      @search_sort      = 'created_at'
      @sort_direction   = 'desc'
      @result_json      = { :results => [], :current_page => @current_page }
    end

    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_agent_models
      @@esv2_agent_topic_merge ||= {
        'topic' => { model: 'Topic', associations: [{ forum: :forum_category }, :user ] }
      }
    end

end