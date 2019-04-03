module Ember
  module Solutions
    class ArticlesController < ApiSolutions::ArticlesController
      include HelperConcern
      include SolutionConcern
      include Solution::ArticleFilters
      include BulkActionConcern
      include SolutionBulkActionConcern
      include CloudFilesHelper
      include SanitizeSerializeValues

      SLAVE_ACTIONS = %w(index folder_articles filter).freeze

      skip_before_filter :initialize_search_parameters, unless: :search_articles?
      before_filter :filter_ids, only: [:index]
      before_filter :validate_language, only: [:filter, :bulk_update]
      before_filter :validate_filter, only: [:article_content, :filter]
      before_filter :sanitize_filter_data, :reconstruct_params, only: [:filter]
      before_filter :validate_bulk_update_article_params, only: [:bulk_update]
      around_filter :use_time_zone, only: [:filter]

      decorate_views(decorate_object: [:article_content, :votes])

      MAX_IDS_COUNT = 10

      def index
        @user = User.find_by_id(params[:user_id]) if params[:user_id].present?
        super
      end

      def filter
        @delegator_klass = "ApiSolutions::ArticleDelegator"
        return unless validate_delegator(nil, portal_id: params[:portal_id])
        search_articles if params[:term].present?
        @portal_articles = scoper.portal_articles(params[:portal_id], @lang_id).preload(filter_preload_options)
        @items = apply_scopes(@portal_articles,  @reorg_params)
        @items = properties_and_term_filters
        @items_count = @items.size
        @items = paginate_items(@items)
        response.api_root_key = :articles
        response.api_meta = { count: @items_count, next_page: @more_items }
      end

      def article_content
        load_article
      end

      def bulk_update
        @succeeded_list = []
        @failed_list = []
        @article_meta = meta_scoper.where(id: cname_params[:ids]).preload(:solution_folder_meta, primary_article: [:solution_folder_meta, :article_body])
        @article_meta.each do |article_meta|
          if update_article_properties(article_meta)
            @succeeded_list << article_meta.id
          else
            @failed_list << (article_meta.errors.any? ? article_meta : article_meta.safe_send(language_scoper))
          end
        end
        render_bulk_action_response(@succeeded_list, @failed_list)
      end

      def reset_ratings
        validate_request_params
        @delegator_klass = 'ApiSolutions::ArticleDelegator'
        return unless validate_delegator(@item)

        @item.reset_ratings ? (head 204) : render_errors(@item.errors)
      end

      def self.wrap_params
        ::SolutionConstants::ARTICLE_WRAP_PARAMS
      end

      private

        def constants_class
          'SolutionsConstants'.freeze
        end

        def render_201_with_location(template_name: "api_solutions/articles/#{action_name}", location_url: 'api_solutions_article_url', item_id: @item.id)
          render template_name, location: safe_send(location_url, item_id), status: 201
        end

        def load_article
          language_id = params[:language_id] || Language.for_current_account.id
          @item = scoper.where(parent_id: params[:id], language_id: language_id).first
          log_and_render_404 unless @item
        end

        def load_objects
          language_id = params[:language_id] || Language.for_current_account.id
          @items = scoper.preload(conditional_preload_options).where(parent_id: @ids, language_id: language_id)
          # Instead of using validation to give 4xx response for bad ids,
          # we are going to tolerate and send response for the good ones alone.
          # Because the primary use case for this is Recently used Solution articles
          log_and_render_404 if @items.blank?
        end

        def conditional_preload_options
          preload_options = ::SolutionConstants::INDEX_PRELOAD_OPTIONS
          return preload_options unless @user
          preload_options | [{ solution_article_meta: [solution_folder_meta: :customer_folders] }]
        end

        def filter_preload_options
          ::SolutionConstants::FILTER_PRELOAD_OPTIONS
        end

        def filter_ids
          params[:ids] = params[:ids].try(:to_s).try(:split, ',') if params[:ids] && params[:ids].is_a?(String)
          @ids = (params[:ids] || []).map(&:to_i).reject(&:zero?).first(MAX_IDS_COUNT)
          log_and_render_404 if @ids.blank?
        end

        def validate_filter
          @constants_klass  = 'SolutionConstants'.freeze
          @validation_klass = 'SolutionArticleFilterValidation'.freeze
          return unless validate_query_params
        end

        def validate_filter_params
          params.permit(*SolutionConstants::RECENT_ARTICLES_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
          @article_filter = SolutionArticleFilterValidation.new(params)
          render_errors(@article_filter.errors, @article_filter.error_options) unless @article_filter.valid?
        end

        def sanitize_filter_data
          filter_fields = SolutionConstants::FILTER_FIELDS
          filter_data   = params.select {|k,v| filter_fields.include? k}
          sanitize_hash_values filter_data
        end

        def properties_and_term_filters
          @items=@items.all # to avoid n+1 queries
          filtered_articles = if params[:term].present?
            ids = @items.map(&:id) & @results.map(&:id)
            @items.select{|item| ids.include?(item.id)}
          else
            @items
          end
          filtered_articles.uniq
        end

        def decorator_options
          options = {}
          options[:user] = @user if @user
          [::Solutions::ArticleDecorator, options]
        end

        def add_attachment_params(builder_params)
          builder_params[:attachments_list] = params[cname][language_scoper][:attachments_list] if params[cname][language_scoper][:attachments_list]
          builder_params[:cloud_file_attachments] = params[cname][language_scoper][:cloud_file_attachments] if params[cname][language_scoper][:cloud_file_attachments]
          builder_params
        end

        def parse_attachment_params
          @article_params[language_scoper][:cloud_file_attachments] = @article_params[language_scoper][:cloud_file_attachments].map(&:to_json) if @article_params[language_scoper][:cloud_file_attachments]
          @article_params[language_scoper][:attachments_list] = @article_params[language_scoper][:attachments_list].join(',') if @article_params[language_scoper][:attachments_list]
        end

        def add_attachments
          parse_attachment_params
          attachment_builder(@draft, nil, (params[cname][language_scoper] || {})[:cloud_file_attachments], (params[cname][language_scoper] || {})[:attachments_list])
        end

        def validate_request_params
          params[cname].permit([])
        end

        # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
        wrap_parameters(*wrap_params)
    end
  end
end
