module Solution::ArticleFilters
  extend ActiveSupport::Concern
  include ::Search::V2::AbstractController

  included do
    has_scope :by_status, type: :hash, using: [:status_data]
    has_scope :by_category, type: :array
    has_scope :by_folder, type: :array
    has_scope :by_created_at, type: :hash, using: [:start, :end]
    has_scope :by_last_modified, type: :hash, using: [:by_last_modified_at, :by_author]
    has_scope :by_tags, type: :array

    def search_articles
      @klasses        = ['Solution::Article']
      @sort_direction = 'desc'
      @search_sort    = 'relevance'
      @search_context = :filtered_solution_search
      @category_ids   = portal_catagory_ids if portal_catagory_ids.present?
      @language_id    = @lang_id
      @results        = esv2_query_results(esv2_agent_article_model)
    end

    private

      def reconstruct_params
        author        = params[:author]
        last_modified = params[:last_modified]
        status        = params[:status]
        reorg_params
        if status
          @reorg_params[:by_status] = { :status_data => {:status => params[:status]} }
          reassign_data(@reorg_params[:by_status][:status_data]) if is_draft?
        end
        @reorg_params[:by_last_modified] = reassign_data if !is_draft? and (author || last_modified)
        @reorg_params
      end

      def reorg_params
        rebuild_params = params.deep_dup
        @reorg_params  = {}.with_indifferent_access
        rebuild_params.each do |key,value|
          key = ::SolutionConstants::FILTER_ATTRIBUTES.include?(key.to_s) ? :"by_#{key}" : key
          @reorg_params.merge!(key => value)
        end
        @reorg_params
      end

      def reassign_data data = {}
        data[:by_author]           = params[:author] if params[:author]
        data[:by_last_modified_at] = params[:last_modified] if params[:last_modified]
        ignore_params
        data
      end

      def is_draft?
        params[:status].to_i == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
      end

      def ignore_params
        ignore_params = is_draft? ? [:by_author, :by_last_modified] : [:by_author]
        ignore_params.each { |param| @reorg_params.delete(param) }
      end

      def esv2_agent_article_model
        {'article' => { model: 'Solution::Article',
          associations: [:user, :article_body, :recent_author, { draft: :draft_body }, 
            { solution_article_meta: { solution_category_meta: :"#{Language.for_current_account.to_key}_category" } }, 
            { solution_folder_meta: [:customer_folders, :"#{Language.for_current_account.to_key}_folder"] }] 
          }
        }
      end

      def construct_es_params
        super.tap do |es_params|
          es_params[:article_category_ids] = @category_ids
          es_params[:language_id] = @language_id || Language.for_current_account.id
          es_params[:size]  = @size
          es_params[:from]  = @offset
        end
      end

      def search_articles?
        params[:action] == 'filter' && params[:term].present?
      end

      def portal_catagory_ids
        @portal_catagory_ids ||= current_account.portal_solution_categories.where(portal_id: params[:portal_id]).pluck(:solution_category_meta_id).uniq
      end
  end
end