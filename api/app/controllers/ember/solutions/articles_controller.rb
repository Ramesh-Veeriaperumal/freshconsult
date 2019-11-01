module Ember
  module Solutions
    class ArticlesController < ApiSolutions::ArticlesController
      include HelperConcern
      include SolutionConcern
      include Solution::ArticleFilters
      include BulkActionConcern
      include SolutionBulkActionConcern
      include SolutionReorderConcern
      include CloudFilesHelper
      include SanitizeSerializeValues

      SLAVE_ACTIONS = %w[index folder_articles filter untranslated_articles].freeze

      skip_before_filter :initialize_search_parameters, unless: :search_articles?
      before_filter :filter_ids, only: [:index]
      before_filter :modify_and_cleanup_language_param, only: [:article_content]
      before_filter :validate_language, only: [:filter, :bulk_update, :untranslated_articles, :article_content, :index]
      before_filter :check_filter_feature, :modify_and_cleanup_status_param, only: [:filter]
      before_filter :validate_filter, only: [:article_content, :filter, :untranslated_articles]
      before_filter :sanitize_filter_data, :reconstruct_params, only: [:filter, :untranslated_articles]
      before_filter :validate_bulk_update_article_params, only: [:bulk_update]
      before_filter :filter_delegator_validation, only: [:filter, :untranslated_articles]
      around_filter :use_time_zone, only: [:filter, :untranslated_articles]

      decorate_views(decorate_object: [:article_content, :votes])

      MAX_IDS_COUNT = 10
      OUTDATED = 'outdated'.freeze

      def index
        @user = User.find_by_id(params[:user_id]) if params[:user_id].present?
        super
      end

      def filter
        search_articles if params[:term].present?
        @portal_articles = scoper.portal_articles(params[:portal_id], [@lang_id]).preload(filter_preload_options)
        @items = apply_article_scopes(@portal_articles)
        @items = properties_and_term_filters
        paginate_filter_items
      end

      def untranslated_articles
        @items = apply_article_scopes(untranslated_language_articles)
        paginate_filter_items
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
          'SolutionConstants'.freeze
        end

        def render_201_with_location(template_name: "api_solutions/articles/#{action_name}", location_url: 'api_solutions_article_url', item_id: @item.id)
          render template_name, location: safe_send(location_url, item_id), status: 201
        end

        def load_article
          @item = scoper.where(parent_id: params[:id], language_id: @lang_id).first
          log_and_render_404 unless @item
        end

        def untranslated_language_articles
          translated_ids = current_account.solution_articles.portal_articles(params[:portal_id], @lang_id).pluck(:parent_id)
          Solution::Article.portal_articles(params[:portal_id], current_account.language_object.id).where('parent_id NOT IN (?)', (translated_ids.presence || '')).preload(untranslated_articles_preload_options)
        end

        def load_objects
          @items = scoper.preload(conditional_preload_options).where(parent_id: @ids, language_id: @lang_id)
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

        def validate_filter_params(addtional_fields = [])
          return unless modify_and_cleanup_language_param
          params.permit(*SolutionConstants::RECENT_ARTICLES_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS, *addtional_fields)
          @article_filter = SolutionArticleFilterValidation.new(params)
          render_errors(@article_filter.errors, @article_filter.error_options) unless @article_filter.valid?
        end

        def sanitize_filter_data
          filter_fields = SolutionConstants::FILTER_FIELDS
          filter_data   = params.select { |k, v| filter_fields.include? k }
          sanitize_hash_values filter_data
        end

        def sanitize_hash_values(filter_data)
          filter_data.each do |key, value|
            next if [true, false].include?(value)

            filter_data[key] = sanitize_value(value)
          end
        end

        def properties_and_term_filters
          # uniq is needed for tags filter, if article contains mutliple tags and filtered by the same set of tags
          if params[:term].present?
            @items.where('solution_articles.id in (?)', @results.map(&:id)).uniq
          else
            @items.uniq
          end
        end

        def decorator_options
          options = {}
          options[:user] = @user if @user
          [::Solutions::ArticleDecorator, options]
        end

        def reorder_scoper
          @reorder_item.solution_folder_meta.solution_article_meta
        end

        def load_reorder_item
          @reorder_item ||= load_meta(params[:id])
          log_and_render_404 unless @reorder_item
          @reorder_item
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

        def check_filter_feature
          render_request_error(:require_feature, 403, feature: :article_filters) unless current_account.article_filters_enabled? || (params.keys & SolutionConstants::ADVANCED_FILTER_FIELDS).empty?
        end

        def untranslated_articles_preload_options
          [{ solution_folder_meta: [{ solution_category_meta: :primary_category }, :primary_folder] }, :draft]
        end

        def filter_delegator_validation
          @delegator_klass = 'ApiSolutions::ArticleDelegator'
          return unless validate_delegator(nil, portal_id: params[:portal_id])
        end

        def paginate_filter_items
          @items_count = @items.size
          @items = paginate_items(@items)
          @items = reorder_articles_by_relevance if params[:term].present?
          response.api_root_key = :articles
          response.api_meta = { count: @items_count, next_page: @more_items }
        end

        def reorder_articles_by_relevance
          items_map = {}
          @items.map { |item| items_map[item.id] = item }
          ordered_items = []
          @results.map { |result| ordered_items.push(items_map[result.id]) if items_map.keys.include?(result.id) }
          ordered_items
        end

        def modify_and_cleanup_language_param
          return true unless params[:language_id]

          language = Language.find(params[:language_id])
          log_and_render_404 && return unless language
          params[:language] = language.code
          params.delete(:language_id)
        end

        def modify_and_cleanup_status_param
          return true unless params[:status] == OUTDATED

          params[:outdated] = true
          params.delete(:status)
        end

        # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
        wrap_parameters(*wrap_params)
    end
  end
end
