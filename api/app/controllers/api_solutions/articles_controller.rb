module ApiSolutions
  class ArticlesController < ApiApplicationController
    include SolutionConcern
    include Solution::LanguageControllerMethods
    include Helpdesk::TagMethods
    decorate_views(decorate_objects: [:folder_articles])

    def show
      @meta = @item.solution_article_meta
    end

    def destroy
      @meta.destroy
      head 204
    end

    def create
      assign_protected
      render_201_with_location(item_id: @item.parent_id) if manage_article
    end

    def update
      manage_article
    end

    def folder_articles
      if validate_language
        @item = current_account.solution_folder_meta.find_by_id(params[:id] || params[:folder_id])
        if @item
          @items = paginate_items(@item.solution_articles.where(language_id: @lang_id))
          render '/api_solutions/articles/index'
        else
          log_and_render_404
        end
      else
        return false
      end
    end

    private

      def scoper
        current_account.solution_articles
      end

      def meta_scoper
        current_account.solution_article_meta
      end

      def manage_article
        delegator_params = { language_id: @lang_id, current_user_id: api_current_user.id, article_meta: @meta, category_name: @category_name, folder_name: @folder_name }
        delegator_params.merge!(user_id: @article_params[language_scoper][:user_id]) if  @article_params[language_scoper] && @article_params[language_scoper][:user_id]
        article_delegator = ArticleDelegator.new(delegator_params)
        if article_delegator.valid?
          @meta = Solution::Builder.article(solution_article_meta: @article_params, language_id: @lang_id)
          @item = @meta.send(language_scoper)
          @item.tags = construct_tags(@tags) if @tags
          @item.create_draft_from_article if @status == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
          if @item.errors.any?
            render_custom_errors
          else
            return true
          end
        else
          render_custom_errors(article_delegator, true)
        end
        false
      end

      def folder_exists?
        @item = current_account.solution_folder_meta.find_by_id(params[:id] || params[:folder_id])
        log_and_render_404 unless @item
      end

      # Load folder if create endpoint is triggered with primitive language
      def load_folder
        folder_exists? if @lang_id == current_account.language_object.id
      end

      def before_load_object
        validate_language
      end

      def load_object(items = scoper)
        @meta = load_meta(params[:id])
        @item = items.where(parent_id: params[:id], language_id: @lang_id).first
        log_and_render_404 unless @item
      end

      def validate_params
        if create?
          return false unless validate_language
          load_folder
        end
        fields = "SolutionConstants::#{action_name.upcase}_ARTICLE_FIELDS".constantize
        params[cname].permit(*(fields))
        article = ApiSolutions::ArticleValidation.new(params[cname], @item, @lang_id)
        render_errors article.errors, article.error_options unless article.valid?(action_name.to_sym)
      end

      def sanitize_params
        prepare_array_fields [:tags]
        sanitize_seo_params
        sanitize_language_params
        params[cname][folder] = params[:id]
        ParamsHelper.assign_and_clean_params({ type: :art_type }, params[cname])
        @status = params[cname][:status]
        @tags = params[cname][:tags]
        @article_params = params[cname].except!(:title, :description, :status, :seo_data)
      end

      def sanitize_seo_params
        if params[cname].key?(:seo_data) && params[cname][:seo_data]['meta_keywords']
          params[cname][:seo_data]['meta_keywords'] = params[cname][:seo_data]['meta_keywords'].each(&:strip!).uniq.join(',')
        end
      end

      def sanitize_language_params
        language_params = params[cname].slice(:title, :description, :status, :seo_data)
        language_params[:user_id] = user_id if user_id
        params[cname][language_scoper] = language_params unless language_params.empty?
      end

      def folder
        params[:language].nil? && create? ? :solution_folder_meta_id : :id
      end

      def user_id
        create? ? api_current_user.id : params[cname][:user_id]
      end

      def assign_protected
        params_hash = params[cname]
        @folder_name = params_hash['folder_name']
        @category_name = params_hash['category_name']
        if params_hash['folder_name']
          @article_params['solution_folder_meta'] = { "#{language.to_key}_folder" => { 'name' => @folder_name }, 'id' => @meta.solution_folder_meta.id }
          if params_hash['category_name']
            @article_params['solution_folder_meta']['solution_category_meta'] = { "#{language.to_key}_category" => { 'name' => @category_name }, 'id' => @meta.solution_category_meta.id }
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
            render_base_error(:method_not_allowed, 405, methods: 'GET, PUT', fired_method: 'POST')
          end
        end
      end

      def load_meta(id)
        meta = meta_scoper.find_by_id(id)
        log_and_render_404 unless meta
        meta
      end
  end
end
