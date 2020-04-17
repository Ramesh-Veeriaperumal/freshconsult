module ApiSearch
  class SolutionsController < Ember::Search::SpotlightController
    ROOT_KEY = :article

    before_filter :convert_language_code, only: [:results]

    def results
      @klasses = ['Solution::Article']
      @category_id = params[:category_id].to_i if params[:category_id].present?
      @category_ids = params[:category_ids] if params[:category_ids].present?
      @folder_id = params[:folder_id].to_i if params[:folder_id].present?
      @sort_direction = 'desc'
      @search_sort  = params[:search_sort] if params[:search_sort].present?
      @language_id  = params[:language] if params[:language].present? && valid_language?(params[:language])
      @user = User.find_by_id(params[:user_id]) if params[:user_id].present?

      if params[:context] == 'spotlight'
        @search_context = :agent_spotlight_solution
      elsif params[:context] == 'insert_solutions'
        @search_context = :agent_insert_solution
      elsif bot_map_context? || portal_based_solutions? || help_widget_based_solutions?
        @search_context = :filtered_solution_search
      else
        @search_context = :agent_spotlight_solution
      end

      @items = esv2_query_results(esv2_agent_models)
      response.api_meta = { count: @items.total_entries }
      @items = [] if @count_request
      @items.reject! { |item| item.parent.nil? || item.parent.solution_folder_meta.nil? || item.parent.solution_folder_meta.solution_category_meta.nil? }
    end

    private

      def bot_map_context?
        params[:context] == 'bot_map_solution'
      end

      def portal_based_solutions?
        params[:context] == 'portal_based_solutions'
      end

      def help_widget_based_solutions?
        params[:context] == 'help_widget_based_solutions'
      end

      def decorator_options
        options = {}
        options[:user] = @user if @user
        options[:search_context] = @search_context if @search_context
        [::Solutions::ArticleDecorator, options]
      end

      def construct_es_params
        super.tap do |es_params|
          es_params[:article_category_id] = @category_id
          es_params[:article_folder_id] = @folder_id
          es_params[:article_category_ids] = @category_ids
          if bot_map_context? || help_widget_based_solutions?
            #To skip draft articles in search
            es_params[:article_status] = Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
          end
          es_params[:article_visibilities] = Solution::Constants::BOT_VISIBILITIES if bot_map_context?
          es_params[:language_id] = @language_id || Language.for_current_account.id

          unless @search_sort.to_s == 'relevance'
            es_params[:sort_by]         = @search_sort
            es_params[:sort_direction]  = @sort_direction
          end

          es_params[:size]  = @size
          es_params[:from]  = @offset
        end
      end

      def convert_language_code
        if !params[:language].present? && params[:language_code] 
          language = Language.find_by_code(params[:language_code])
          return unless language
          params[:language] = language.id
          params.delete(:language_code)
        end
      end

      def valid_language?(language_id)
        Language.find(language_id).present?
      end
  end
end
