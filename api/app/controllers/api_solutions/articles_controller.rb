module ApiSolutions
  class ArticlesController < ApiApplicationController
    include SolutionConcern
    include HelperConcern
    include Solution::LanguageControllerMethods
    include Helpdesk::TagMethods
    include CloudFilesHelper

    SLAVE_ACTIONS = %w[index folder_articles].freeze

    decorate_views(decorate_objects: [:folder_articles])
    before_filter :validate_query_parameters, only: [:folder_articles]
    before_filter :validate_draft_state, only: [:update, :destroy]
    before_filter :language_metric_presence

    def show
      @meta = @item.solution_article_meta
    end

    def destroy
      @meta.destroy
      head 204
    end

    def create
      assign_protected
      return unless delegator_validation

      render_201_with_location(item_id: @item.parent_id) if create_or_update_article
    end

    def update
      return unless delegator_validation

      # for an article with unassociated folder, folder needs to be set before publishing the article
      @item.solution_article_meta.update_attributes(solution_folder_meta_id: @article_params[:folder_id]) if @article_params.key?(:folder_id)
      if @status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published] && @draft
        @draft.publish!
      elsif @article_params[language_scoper] && @status == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft] && !article_properties? && !unpublish?
        @draft ||= @item.build_draft_from_article
        @draft.unlock # So that the lock in period for 'editing' status is reset
        assign_draft_attributes(@article_params)
        add_attachments if private_api?
        render_custom_errors(@draft, true) unless @draft.save
        remove_lang_scoper_params
      end
      remove_lang_scoper_params if !unpublish? && article_properties?
      create_or_update_article
    end

    def folder_articles
      if validate_language
        if load_folder
          load_folder_articles
          if private_api?
            # removing description, attachments, tags for article list api in two pane to improve performance
            @exclude = [:description, :attachments, :tags]
            response.api_root_key = :articles
            response.api_meta = { count: @items_count, next_page: @more_items }
          end
          render '/api_solutions/articles/index'
        end
      else
        false
      end
    end

    def self.wrap_params
      SolutionConstants::ARTICLE_WRAP_PARAMS
    end

    private

      def scoper
        current_account.solution_articles
      end

      def meta_scoper
        current_account.solution_article_meta
      end

      def create_or_update_article
        if !construct_article_object
          render_solution_item_errors
        else
          return true
        end
        false
      end

      def delegator_validation
        @delegator_klass = 'ApiSolutions::ArticleDelegator'.freeze
        validate_delegator(@item, delegator_params)
      end

      def load_folder_articles
        items = @folder.solution_articles.where(language_id: @lang_id).reorder(Solution::Constants::ARTICLE_ORDER_COLUMN_BY_TYPE[@folder.article_order]).preload(
          {
            solution_article_meta: [
              :solution_folder_meta,
              :solution_category_meta
            ]
          },
          :article_body, :tags, :attachments, { cloud_files: :application }, :draft, draft: [:draft_body, :attachments, :cloud_files]
        )
        @items_count = items.count if private_api?
        @items = paginate_items(items)
      end

      def remove_lang_scoper_params
        @article_params[language_scoper].delete_if { |k, v| !SolutionConstants::ARTICLE_PROPERTY_FIELDS.include?(k) } if @article_params[language_scoper].present?
      end

      def article_properties?
        # Only article properties are changed.
        (SolutionConstants::ARTICLE_PROPERTY_FIELDS.any? { |key| @article_params[language_scoper].key?(key) || @article_params.key?(key) }) && @article_params[language_scoper].except(:status, :unlock, *SolutionConstants::ARTICLE_PROPERTY_FIELDS).keys.empty?
      end

      def unpublish?
        # If only status is present in params, then it means unpublish article
        @article_params[language_scoper].keys.length == 1 && @article_params[language_scoper].key?(:status)
      end

      def construct_article_object
        parse_attachment_params if private_api?
        article_builder_params = { solution_article_meta: @article_params, language_id: @lang_id }
        @meta = Solution::Builder.article(article_builder_params)
        @item = @meta.safe_send(language_scoper)
        @item.tags = @tags if @tags
        @item.create_draft_from_article if @status == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft] && create?
        !(@item.errors.any? || @item.parent.errors.any?)
      end

      def assign_draft_attributes(lang_params)
        @draft.title = lang_params[language_scoper][:title] if lang_params[language_scoper][:title].present?
        @draft.description = lang_params[language_scoper][:description] if lang_params[language_scoper][:description].present?
      end

      def delegator_params
        delegator_params = { language_id: @lang_id, article_meta: @meta, tags: @tags }
        delegator_params[:folder_name] = params[cname]['folder_name'] if params[cname].key?('folder_name')
        delegator_params[:category_name] = params[cname]['category_name'] if params[cname].key?('category_name')
        delegator_params[:user_id] = @article_params[language_scoper][:user_id] if @article_params[language_scoper] && @article_params[language_scoper][:user_id]
        delegator_params = add_attachment_params(delegator_params) if private_api?
        delegator_params
      end

      def before_load_object
        validate_language
      end

      def load_object(items = scoper)
        @meta = load_meta(params[:id])
        @item = items.where(parent_id: params[:id], language_id: @lang_id).preload(cloud_files: :application).first
        if @item
          @draft = @item.draft
        else
          log_and_render_404
        end
      end

      def validate_params
        return false unless validate_create_params
        validate_request_keys
        @status = params[cname][:status].to_i if params[cname][:status]

        # Maintaining the same flow for attachments as in articles_controller
        attachable = if @draft
                       @draft
                     elsif @status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
                       @item
                     end

        article_obj = private_api? ? nil : @item # for private api existing obj should not be validated, only the body params should be validated.
        article = ApiSolutions::ArticleValidation.new(
          params[cname], article_obj, attachable, @lang_id, string_request_params?
        )
        unless article.valid?(action_name.to_sym)
          render_errors article.errors,
                        article.error_options
        end
      end

      def validate_create_params
        return true unless create?
        return false if !validate_language || (@lang_id == current_account.language_object.id && !load_folder)
        true
      end

      def validate_request_keys
        fields = "SolutionConstants::#{action_name.upcase}_ARTICLE_FIELDS"
        params[cname].permit(*get_fields(fields))
      end

      def validate_draft_state
        render_request_error_with_info(:draft_locked, 400, {}, user_id: @draft.user_id) if @draft && @draft.locked?
      end

      def language_metric_presence
        @language_metric = private_api? || params.key?(:language) # Needed to fetch overall/language metrics in public api call.
      end

      def remove_ignore_params
        params[cname].except!(SolutionConstants::IGNORE_PARAMS)
      end

      def sanitize_params
        language_params_hash = params[cname][language_scoper]
        prepare_array_fields [:tags, :attachments]
        ParamsHelper.assign_and_clean_params({ type: :art_type, agent_id: :user_id }, params[cname])
        sanitize_seo_params
        sanitize_language_params
        sanitize_attachment_params
        params[cname][folder] = params[:id]
        @tags = construct_tags(params[cname][:tags]) if params[cname] && params[cname][:tags]
        # To ensure if both title and description are present in params
        if language_params_hash && @draft
          language_params_hash[:title] ||= @draft.title
          language_params_hash[:description] ||= @draft.description
        end
        @article_params = params[cname].except!(*SolutionConstants::ARTICLE_LANGUAGE_FIELDS)
      end

      def sanitize_seo_params
        if params[cname].key?(:seo_data) && params[cname][:seo_data]['meta_keywords']
          params[cname][:seo_data]['meta_keywords'] = params[cname][:seo_data]['meta_keywords'].each(&:strip!).uniq.join(',')
        end
      end

      def sanitize_language_params
        language_params = params[cname].slice(*SolutionConstants::ARTICLE_LANGUAGE_FIELDS)
        language_params[:user_id] = user_id if user_id
        params[cname][language_scoper] = language_params
      end

      def sanitize_attachment_params
        params_hash = params[cname][language_scoper]
        if params_hash && params_hash[:attachments]
          params_hash[:attachments] = params_hash[:attachments].map do |att|
            { resource: att }
          end
        end
      end

      def folder
        params[:language].nil? && create? ? :solution_folder_meta_id : :id
      end

      def user_id
        create? ? api_current_user.id : params[cname][:user_id]
      end

      def load_folder
        @folder = current_account.solution_folder_meta.find_by_id(params[:id] || params[:folder_id])
        unless @folder
          log_and_render_404
          return false
        end
        true
      end

      def assign_protected
        params_hash = params[cname]
        if params_hash['folder_name']
          @article_params['solution_folder_meta'] = { "#{language.to_key}_folder" => { 'name' => params_hash['folder_name'] }, 'id' => @meta.solution_folder_meta.id }
          if params_hash['category_name']
            @article_params['solution_folder_meta']['solution_category_meta'] = { "#{language.to_key}_category" => { 'name' => params_hash['category_name'] }, 'id' => @meta.solution_category_meta.id }
          end
        end
      end

      def build_object
        if params.key?(:id) && params.key?(:language)
          @meta = load_meta(params[:id])
          @item = scoper.where(parent_id: params[:id], language_id: @lang_id).first
          if @item.nil?
            @item = Solution::Article.new
            params[cname][:user_id] ||= api_current_user.id
          else
            # Not allowed if the request is fired with existing id language combination
            render_base_error(:method_not_allowed, 405, methods: 'GET, PUT', fired_method: 'POST')
          end
        end
      end

      def build_attachments(target_item, attachment_params)
        if attachment_params
          build_normal_attachments(target_item, attachment_params)
          target_item.attachments = target_item.attachments
        end
      end

      def validate_query_parameters
        validate_filter_params(SolutionConstants::INDEX_FIELDS)
      end

      def load_meta(id)
        meta = meta_scoper.find_by_id(id)
        log_and_render_404 unless meta
        meta
      end

      def valid_content_type?
        return true if super
        allowed_content_types = SolutionConstants::ARTICLE_ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym] || [:json]
        allowed_content_types.include?(request.content_mime_type.ref)
      end

      # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
      wrap_parameters(*wrap_params)
  end
end
