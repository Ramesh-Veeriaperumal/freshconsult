module ApiSolutions
  class ArticlesController < ApiApplicationController
    include SolutionConcern
    include Solution::LanguageControllerMethods
    include Helpdesk::TagMethods
    include CloudFilesHelper

    decorate_views(decorate_objects: [:folder_articles])
    before_filter :validate_filter_params, only: [:folder_articles]

    def show
      @meta = @item.solution_article_meta
    end

    def destroy
      @meta.destroy
      head 204
    end

    def create
      assign_protected
      render_201_with_location(item_id: @item.parent_id) if create_or_update_article
    end

    def update
      if @status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published] && @draft
        @draft.publish!
      elsif @article_params[language_scoper] && @status == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
        @draft = @item.build_draft_from_article unless @draft
        attachment_params = @article_params[language_scoper].delete(:attachments)
        build_attachments(@draft, attachment_params)
        @draft.unlock
        language_params = @article_params[language_scoper].extract!(:title, :description)
        @draft.update_attributes(language_params)
        # Deleting the language_scoper params except seo_data from hash as seo_data
        # must be updated for article and rest should only be updated for draft
        unless @article_params[language_scoper].present?
          @article_params[language_scoper].delete_if { |k, v| k != :seo_data }
        end
      end
      create_or_update_article
    end

    def folder_articles
      if validate_language
        if load_folder
          @items = paginate_items(
            @folder.solution_articles.where(language_id: @lang_id).preload(
              {
                solution_article_meta: [
                  :solution_folder_meta,
                  :solution_category_meta
                ]
              },
              :article_body, :draft, draft: :draft_body
            )
          )
          render '/api_solutions/articles/index'
        end
      else
        return false
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
        article_delegator = build_article_delegator
        if !article_delegator.valid?
          render_custom_errors(article_delegator, true)
        elsif !construct_article_object
          render_solution_item_errors
        else
          return true
        end
        false
      end

      def construct_article_object
        @meta = Solution::Builder.article(solution_article_meta: @article_params, language_id: @lang_id)
        @item = @meta.send(language_scoper)
        @item.tags = construct_tags(@tags) if @tags
        @item.create_draft_from_article if @status == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft] && create?
        !(@item.errors.any? || @item.parent.errors.any?)
      end

      def build_article_delegator
        delegator_params = { language_id: @lang_id, article_meta: @meta }
        delegator_params[:folder_name] = params[cname]['folder_name'] if params[cname].key?('folder_name')
        delegator_params[:category_name] = params[cname]['category_name'] if params[cname].key?('category_name')
        delegator_params[:user_id] = @article_params[language_scoper][:user_id] if @article_params[language_scoper] && @article_params[language_scoper][:user_id]
        ArticleDelegator.new(delegator_params)
      end

      def before_load_object
        validate_language
      end

      def load_object(items = scoper)
        @meta = load_meta(params[:id])
        @item = items.where(parent_id: params[:id], language_id: @lang_id).first
        if @item
          @draft = @item.draft
        else
          log_and_render_404
        end
      end

      def validate_params
        if create?
          return false unless validate_language
          # Load folder if create endpoint is triggered with primitive language
          return false if @lang_id == current_account.language_object.id && !load_folder
        end
        fields = "SolutionConstants::#{action_name.upcase}_ARTICLE_FIELDS"
        params[cname].permit(*get_fields(fields))

        @status = params[cname][:status].to_i if params[cname][:status]

        # Maintaining the same flow for attachments as in articles_controller
        attachable = if @draft
                       @draft
                     elsif @status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
                       @item
                     end

        article = ApiSolutions::ArticleValidation.new(
          params[cname], @item, attachable, @lang_id, string_request_params?
        )
        render_errors article.errors,
                      article.error_options unless article.valid?(action_name.to_sym)
      end

      def sanitize_params
        language_params_hash = params[cname][language_scoper]
        prepare_array_fields [:tags, :attachments]
        ParamsHelper.assign_and_clean_params({ type: :art_type, agent_id: :user_id }, params[cname])
        sanitize_seo_params
        sanitize_language_params
        sanitize_attachment_params
        params[cname][folder] = params[:id]
        @tags = params[cname][:tags]
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

      def validate_filter_params
        super(SolutionConstants::INDEX_FIELDS)
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
