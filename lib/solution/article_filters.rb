module Solution::ArticleFilters
  extend ActiveSupport::Concern
  include ::Search::V2::AbstractController

  included do
    has_scope :by_status
    has_scope :by_category, type: :array
    has_scope :by_folder, type: :array
    has_scope :by_created_at, type: :hash, using: [:start, :end]
    has_scope :by_author, type: :hash, using: [:author, :only_draft]
    has_scope :by_last_modified, type: :hash, using: [:start, :end, :only_draft]
    has_scope :by_tags, type: :array
    has_scope :by_outdated, type: :boolean, allow_blank: true

    def search_articles
      @klasses        = ['Solution::Article']
      @sort_direction = 'desc'
      @search_sort    = 'relevance'
      @search_context = :filtered_solution_search
      @category_ids   = portal_catagory_ids if portal_catagory_ids.present?
      @language_id    = @lang_id
      @results        = esv2_query_results(esv2_agent_article_model)
    end

    def apply_article_scopes(article_scoper)
      if is_draft?
        @join_type = 'INNER'
        @order_by = 'solution_drafts.modified_at desc'
      else
        @join_type = 'LEFT'
        @order_by = 'IFNULL(solution_drafts.modified_at, solution_articles.modified_at) desc'
      end
      join_sql = format(%(%{join_type} JOIN solution_drafts ON solution_drafts.article_id = solution_articles.id AND solution_drafts.account_id = %{account_id}), account_id: Account.current.id, join_type: @join_type)
      apply_scopes(article_scoper, @reorg_params).joins(join_sql).order(@order_by)
    end

    private

      def reconstruct_params
        author        = params[:author]
        last_modified = params[:last_modified]
        reorg_params
        @reorg_params[:by_last_modified][:only_draft] = is_draft? if last_modified
        @reorg_params[:by_author] = { author: author, only_draft: is_draft? } if author
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

      def is_draft?
        params[:status].present? && params[:status].to_i == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
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