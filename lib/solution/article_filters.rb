module Solution::ArticleFilters
  extend ActiveSupport::Concern

  include SolutionHelper

  included do
    has_scope :by_status, type: :hash, using: [:status, :approver]
    has_scope :by_category, type: :array
    has_scope :by_folder, type: :array
    has_scope :by_created_at, type: :hash, using: [:start, :end]
    has_scope :by_author, type: :hash, using: [:author, :only_draft]
    has_scope :by_last_modified, type: :hash, using: [:start, :end, :only_draft]
    has_scope :by_tags, type: :array
    has_scope :by_outdated, type: :boolean, allow_blank: true
    has_scope :by_platforms, type: :array, if: :allow_chat_platform_attributes?

    def apply_article_scopes(article_scoper)
      if is_draft? && !es_for_filter?
        @join_type = 'INNER'
        @order_by = 'solution_drafts.modified_at desc'
      else
        @join_type = 'LEFT'
        @order_by = 'IFNULL(solution_drafts.modified_at, solution_articles.modified_at) desc'
      end
      join_sql = format(%(%{join_type} JOIN solution_drafts ON solution_drafts.article_id = solution_articles.id AND solution_drafts.account_id = %{account_id}), account_id: Account.current.id, join_type: @join_type)
      es_for_filter? ? article_scoper.joins(join_sql) : apply_scopes(article_scoper.joins(join_sql), @reorg_params).order(@order_by)
    end

    private
      def es_for_filter?
        search_articles? && es_filters_enabled?
      end

      def es_filters_enabled?
        Account.current.launched?(:article_es_search_by_filter)
      end

      def reconstruct_params
        status = params[:status]
        approver = params[:approver]
        author        = params[:author]
        last_modified = params[:last_modified]
        reorg_params
        @reorg_params[:by_last_modified][:only_draft] = is_draft? if last_modified
        @reorg_params[:by_author] = { author: author, only_draft: is_draft? } if author
        @reorg_params[:by_status] = { status: status, approver: approver } if status
        @reorg_params
      end

      def reorg_params
        rebuild_params = params.deep_dup
        @reorg_params  = {}.with_indifferent_access
        rebuild_params.each do |key, value|
          key = ::SolutionConstants::FILTER_ATTRIBUTES.include?(key.to_s) ? :"by_#{key}" : key
          @reorg_params.merge!(key => value)
        end
        @reorg_params
      end

      def is_draft?
        params[:status].present? && params[:status].to_i == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
      end

      def esv2_agent_article_model
        { 'article' => { model: 'Solution::Article',
                         associations: [:user, :article_body, :recent_author, { draft: :draft_body },
                                        { solution_article_meta: { solution_category_meta: :"#{Language.for_current_account.to_key}_category" } },
                                        { solution_folder_meta: [:customer_folders, :"#{Language.for_current_account.to_key}_folder"] }] } }
      end

      def construct_es_params
        super.tap do |es_params|
          es_params[:article_category_ids] = @category_ids
          if es_filters_enabled?
            es_params[:article_category_ids] = params[:category] if params[:category].present?
            es_params[:article_tags] = params[:tags].join('","') if params[:tags].present?
            es_query = construct_es_query
            es_params[:query] = es_query unless es_query.empty?
          end
          es_params[:language_id] = @language_id || Language.for_current_account.id
          es_params[:size]  = @size
          es_params[:from]  = @offset
        end
      end

      def construct_es_query
        conditions = []
        params_hash = params.to_h.deep_symbolize_keys
        conditions.push(es_status_condition(params_hash)) if params[:status]
        if params[:author]
          author_conditions = format('user_id:%{author} OR draft_modified_by:%{author}', params_hash)
          conditions.push(format('(%s)', is_draft? ? author_conditions : format('%s OR modified_by:%s', author_conditions, params[:author])))
        end
        conditions.push(format("(created_at:>'%{start}' AND created_at:<'%{end}')", start: es_iso_format(params_hash[:created_at][:start]), end: es_iso_format(params_hash[:created_at][:end]))) if params[:created_at]
        conditions.push(format("((modified_at:>'%{start}' AND modified_at:<'%{end}') OR (draft_modified_at:>'%{start}' AND draft_modified_at:<'%{end}'))", start: es_iso_format(params_hash[:last_modified][:start]), end: es_iso_format(params_hash[:last_modified][:end]))) if params[:last_modified]
        conditions.push(format('(outdated:true)')) if params[:outdated]
        conditions.push(format('approvers:%{approver}', params_hash)) if params[:approver]
        conditions.push(format('(%s)', params[:platforms].collect { |x| format('platforms:%s', x) }.join(' OR '))) if params[:platforms].present?
        conditions.push(format('(%s)', params[:folder].collect { |x| format('folder_id:%s', x) }.join(' OR '))) if params[:folder].present?
        conditions.join(' AND ')
      end

      def es_iso_format(input_time)
        Time.iso8601(input_time).iso8601
      end

      def search_articles?
        params[:action] == 'filter' && params[:term].present?
      end

      def portal_catagory_ids
        @portal_catagory_ids ||= current_account.portal_solution_categories.where(portal_id: params[:portal_id]).pluck(:solution_category_meta_id).uniq
      end

      def get_date_range(date_value)
        end_of_day = Time.zone.now.end_of_day
        case date_value
        when 'today' then
          return fetch_date_range(Time.zone.now.beginning_of_day, end_of_day)
        when 'yesterday' then
          return fetch_date_range(Time.zone.now.yesterday.beginning_of_day, Time.zone.now.yesterday.end_of_day)
        when 'this_week' then
          return fetch_date_range(Time.zone.now.beginning_of_week, Time.zone.now.end_of_week)
        when '7days' then
          return fetch_date_range(Time.zone.now.beginning_of_day.ago(7.days), end_of_day)
        when 'this_month' then
          return fetch_date_range(Time.zone.now.beginning_of_month, Time.zone.now.end_of_month)
        when '30days' then
          return fetch_date_range(Time.zone.now.beginning_of_day.ago(30.days), end_of_day)
        when '60days' then
          return fetch_date_range(Time.zone.now.beginning_of_day.ago(60.days), end_of_day)
        when '180days' then
          return fetch_date_range(Time.zone.now.beginning_of_day.ago(180.days), end_of_day)
        end
      end

      def fetch_date_range(from, to)
        { start: from.utc.iso8601, end: to.utc.iso8601 }
      end

      def es_status_condition(params_hash)
        case params[:status].to_i
        when SolutionConstants::STATUS_FILTER_BY_TOKEN[:draft] then
          return format('(-draft_status:%{status})', status: Solution::Article::DRAFT_STATUSES_ES[:draft_not_present])
        when SolutionConstants::STATUS_FILTER_BY_TOKEN[:published] then
          return format('(status:%{status})', params_hash)
        when SolutionConstants::STATUS_FILTER_BY_TOKEN[:in_review], SolutionConstants::STATUS_FILTER_BY_TOKEN[:approved]
          return format('(draft_status:%{status})', status: SolutionConstants::STATUS_VALUE_IN_ES_BY_KEY[params_hash[:status].to_i])
        end
      end
  end
end
