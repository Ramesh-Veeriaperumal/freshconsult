module ApiSolutions
  class ArticlesController < ApiApplicationController
    include SolutionConcern
    include HelperConcern
    include Solution::LanguageControllerMethods
    include Helpdesk::TagMethods
    include CloudFilesHelper
    include Solution::ArticleFilters

    SLAVE_ACTIONS = %w[index folder_articles].freeze
    STATUS_KEYS_BY_TOKEN = Solution::Article::STATUS_KEYS_BY_TOKEN

    decorate_views(decorate_objects: [:folder_articles])
    before_filter :validate_query_parameters, only: [:folder_articles], unless: :channel_v2?
    before_filter :validate_draft_state, only: [:update, :destroy]
    before_filter :language_metric_presence
    before_filter :validate_publish_solution_privilege, only: [:update, :create]

    def show
      @prefer_published = params[:prefer_published].to_bool unless params[:prefer_published].nil?
      @meta = @item.solution_article_meta
    end

    def destroy
      @meta.destroy
      head 204
    end

    # for create article usecase is simple. create article with all the desired properties, if the status is draft, create draft from aritcle.
    def create
      assign_protected
      return unless delegator_validation
      render_201_with_location(item_id: @item.parent_id) if create_or_update_article
    end

    # Article update can modify 3 models at the same time, article_meta, article, draft.
    # there are common properties between draft and article, such as title and description (check solution constants).
    # if status is draft, common properties updated to draft, else updated to article.
    # while publishing all common properties updated via draft if draft exisits. i.e, update draft model with draft properties and publish the draft.
    # if draft not exisits, update directly on article.
    def update
      return unless delegator_validation

      # for an article with unassociated folder, folder needs to be set before publishing the article
      @item.solution_article_meta.solution_folder_meta_id = @article_params[:folder_id] if @article_params.key?(:folder_id)

      if @status == STATUS_KEYS_BY_TOKEN[:published] && @draft
        # When article is published with content change and without autosave we need to make sure draft has updated content
        assign_draft_attributes(@article_params[language_scoper])
        @article_params[language_scoper].delete(:status)
        set_session
        @draft.publish!
      elsif !@draft_params.empty? && @status == STATUS_KEYS_BY_TOKEN[:draft]
        @draft ||= @item.build_draft_from_article
        set_session
        @draft.unlock # So that the lock in period for 'editing' status is reset
        assign_draft_attributes(@draft_params)
        render_custom_errors(@draft) unless @draft.save
      elsif @draft
        # draft should be unlocked in all update cases
        set_session
        @draft.unlock!(true)
      end
      # we should send status in all the cases, that might not have effect on somecases. thus removing it from article update.
      skip_status_update_if_possible

      # clear approvals if there are any changes that's visible to user.
      @item.clear_approvals if @item.status == STATUS_KEYS_BY_TOKEN[:draft] && current_account.article_approval_workflow_enabled? && publishable_article_properties?
      create_or_update_article
    end

    def folder_articles
      if validate_language
        if load_folder
          @prefer_published = params[:prefer_published].to_bool unless params[:prefer_published].nil?
          load_folder_articles
          if private_api?
            # removing description, attachments, tags for article list api in two pane to improve performance
            @exclude = [:description, :attachments, :tags, :translation_summary]
            response.api_root_key = :articles
            response.api_meta = { count: @items_count, next_page: @more_items }
          elsif channel_v2? && allow_chat_platform_attributes?
            @exclude = [:description, :attachments]
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

      def validate_publish_solution_privilege
        return if publish_privilege?
        # create : To send stauts as published in create call, user should have publish solution privilege
        # update : User can publish approved article, or can update non-publishable article properties.
        if create? ? @status == STATUS_KEYS_BY_TOKEN[:published] : !publishing_approved_article? && changing_published_properties?
          error_info_hash = { details: 'dont have permission to perfom on published article' }
          render_request_error_with_info(:published_article_privilege_error, 403, error_info_hash, error_info_hash)
        end
      end

      def skip_status_update_if_possible
        # for only unpublish and publish action, we can't skip status update
        unless (article_fields_to_update - [:status]).empty?
          is_dummy_status = @draft ? (@status == STATUS_KEYS_BY_TOKEN[:draft]) : (@status == STATUS_KEYS_BY_TOKEN[:published])
          @article_params[language_scoper].delete(:status) if is_dummy_status
        end
      end

      def publish_privilege?
        api_current_user.privilege?(:publish_solution)
      end

      def publishing_approved_article?
        return false unless current_account.article_approval_workflow_enabled?
        (api_current_user.privilege?(:publish_approved_solution) && only_publish? && @item.helpdesk_approval.try(:approved?))
      end

      # This returns true if update call making any changes that's visible to user.
      # ex, changing title, desc, folder, etc
      def changing_published_properties?
        is_changing = only_status? # only publish or unpublish
        is_changing ||= @draft && @status == STATUS_KEYS_BY_TOKEN[:published] # publishing the draft.
        is_changing ||= @item.status == STATUS_KEYS_BY_TOKEN[:published] && publishable_article_properties? # any changes made on article while the article is already in published state
        is_changing
      end

      def set_session
        # For autosave in versioning
        @item.session = @session
        @draft.session = @session if @draft
      end

      def load_folder_articles
        items = params[:portal_id].present? ? @folder.solution_articles.portal_articles(params[:portal_id], [@lang_id]) : @folder.solution_articles.where(language_id: @lang_id)
        items = items.reorder(Solution::Constants::ARTICLE_ORDER_COLUMN_BY_TYPE[@folder.article_order]).preload(
          {
            solution_article_meta: [
              :solution_folder_meta,
              :solution_category_meta
            ]
          },
          :article_body, :tags, :attachments, { cloud_files: :application }, :draft, draft: [:draft_body, :attachments, :cloud_files]
        )
        @items_count = items.count if private_api?
        @items = tags_or_platforms_present? ? paginate_items(apply_article_scopes(items)) : paginate_items(items)
      end

      def chat_params_present?
        ((SolutionConstants::FOLDER_ARTICLES_FIELDS - SolutionConstants::INDEX_FIELDS) & params.keys).present?
      end

      def publishable_article_properties?
        # outdated is just a flag in agent portal. that is not visible to customer. thus we can consider it as non-publishable field.
        !(article_fields_to_update - [:outdated, :status]).empty?
      end

      def only_publish?
        only_status? && @article_params[language_scoper][:status] == STATUS_KEYS_BY_TOKEN[:published]
      end

      def only_unpublish?
        only_status? && @article_params[language_scoper][:status] == STATUS_KEYS_BY_TOKEN[:draft]
      end

      def only_status?
        fields = article_fields_to_update
        fields.length == 1 && fields.include?(:status)
      end

      # all the properties (aritcle_meta and aritcle) that will be updated in this API call.
      def article_fields_to_update
        (@article_params.slice(*SolutionConstants::UPDATEABLE_ARTICLE_META_FIELDS).keys + @article_params[language_scoper].slice(*SolutionConstants::UPDATEABLE_ARTICLE_LANGUAGE_FIELDS).keys).map(&:to_sym)
      end

      def construct_article_object
        parse_attachment_params(@article_params[language_scoper]) if private_api?
        article_builder_params = { solution_article_meta: @article_params, language_id: @lang_id, tags: @tags, session: @session }
        @meta = Solution::Builder.article(article_builder_params)
        @meta.reload if @meta.solution_platform_mapping && @meta.solution_platform_mapping.destroyed?
        @item = @meta.safe_send(language_scoper)
        @item.create_draft_from_article if @status == STATUS_KEYS_BY_TOKEN[:draft] && create?
        !(@item.errors.any? || @item.parent.errors.any?)
      end

      def assign_draft_attributes(params_hash)
        @draft.title = params_hash[:title] if params_hash[:title].present?
        @draft.description = params_hash[:description] if params_hash[:description].present?
        params_hash.except!(:title, :description)
        add_attachments_to_draft if private_api?
      end

      def delegator_params
        delegator_params = { language_id: @lang_id, article_meta: @meta, tags: @tags }
        delegator_params.merge!(params[cname].slice(:folder_name, :category_name, :user_id, :outdated, :description, :status, :platforms))
        delegator_params = add_attachment_params(delegator_params) if private_api?
        delegator_params.with_indifferent_access
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
        if params[cname][:status]
          @status = params[cname][:status].to_i
        elsif (params[cname].key?('title') || params[cname].key?('description'))
          @status = STATUS_KEYS_BY_TOKEN[:draft]
        end
        # Maintaining the same flow for attachments as in articles_controller
        attachable = if @draft
                       @draft
                     elsif @status == STATUS_KEYS_BY_TOKEN[:published]
                       @item
                     end

        article = ApiSolutions::ArticleValidation.new(
          params[cname], @item, attachable, @lang_id, string_request_params?
        )
        unless article.valid?(action_name.to_sym)
          render_errors article.errors,
                        article.error_options
        end
      end

      def validate_chat_params
        @constants_klass  = 'SolutionConstants'.freeze
        @validation_klass = 'SolutionOmniFilterValidation'.freeze
        return unless validate_query_params
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
        prepare_array_fields [:tags, :attachments]
        # re-map API params to model params.
        ParamsHelper.assign_and_clean_params({ type: :art_type, agent_id: :user_id }, params[cname])
        @session = params[cname][:session]
        params[cname][folder] = params[:id]
        sanitize_user_id_params
        sanitize_seo_params
        sanitize_attachment_params
        @tags = construct_tags(params[cname][:tags]) if params[cname] && params[cname][:tags]
        @article_params = params[cname].slice(*SolutionConstants::ARTICLE_META_FIELDS)
        
        # if it is create call, all properties goes to article model. and draft is created from article.
        @draft_params = create? || (params[cname][:status].to_i == STATUS_KEYS_BY_TOKEN[:published]) ? {} : params[cname].slice(*SolutionConstants::DRAFT_FIELDS)
        
        # remove the params that will be updated to draft and common to article model.
        @article_params[language_scoper] = params[cname].slice(*(SolutionConstants::ARTICLE_LANGUAGE_FIELDS.map(&:to_sym) - (@draft_params.empty? ? [] : @draft_params.keys.map(&:to_sym) + [:status])))
      end

      def sanitize_chat_params
        params[:platforms] = params[:platforms].split(',').uniq if params[:platforms].present?
        params[:tags] = params[:tags].split(',').uniq if params[:tags].present?
      end

      def tags_or_platforms_present?
        (params[:platforms].present? || params[:tags].present?)
      end

      def sanitize_seo_params
        if params[cname].key?(:seo_data) && params[cname][:seo_data]['meta_keywords']
          params[cname][:seo_data]['meta_keywords'] = params[cname][:seo_data]['meta_keywords'].each(&:strip!).uniq.join(',')
        end
      end

      def sanitize_user_id_params
        params[cname][:user_id] = user_id if user_id
      end

      def sanitize_attachment_params
        if params[cname] && params[cname][:attachments]
          params[cname][:attachments] = params[cname][:attachments].map do |att|
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

      def validate_chat_query_parameters(addtional_fields = [])
        validate_filter_params(SolutionConstants::FOLDER_ARTICLES_FIELDS)
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

      def channel_v2?
        self.class == Channel::V2::ApiSolutions::ArticlesController
      end

      # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
      wrap_parameters(*wrap_params)
  end
end
