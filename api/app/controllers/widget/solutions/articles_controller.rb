module Widget
  module Solutions
    class ArticlesController < ApiApplicationController
      include WidgetConcern

      skip_before_filter :check_privilege
      skip_before_filter :load_object, only: [:suggested_articles]

      decorate_views(decorate_objects: [:suggested_articles])

      def suggested_articles
        load_articles
        log_and_render_404 unless @items
      end

      def thumbs_up
        @item.thumbs_up!
        head 204
      end

      def thumbs_down
        @item.thumbs_down!
        head 204
      end

      def hit
        @item.hit!
        head 204
      end

      private

        def scoper
          current_account.solution_article_meta.for_portal(@current_portal).published
        end

        def load_object(items = scoper)
          meta_item = items.find_by_id(params[:id])
          @item = meta_item.current_article if meta_item.present?
          log_and_render_404 if @item.nil?
        end

        def before_load_object
          check_feature
          return if @error.present?

          check_open_solutions
          return if @error.present?

          validate_widget
          return if @error.present?

          set_widget_portal_as_current
          return render_request_error(:solution_article_not_enabled, 400, id: @widget_id) unless @help_widget.solution_articles_enabled?
          
          set_current_language
        end

        def decorator_options
          [::Widget::Solutions::ArticleDecorator, {}]
        end

        def load_articles
          meta_item_ids = scoper.order('solution_article_meta.hits desc').limit(5).pluck(:id)
          @items = current_account.solution_articles.where(parent_id: meta_item_ids, language_id: Language.current.id)
        end
    end
  end
end
