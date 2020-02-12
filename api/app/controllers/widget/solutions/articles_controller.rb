module Widget
  module Solutions
    class ArticlesController < ApiApplicationController
      include WidgetConcern
      include Solution::ArticlesVotingMethods

      RELAXED_ACTIONS = [:suggested_articles, :show].freeze

      decorate_views(decorate_objects: [:suggested_articles])

      skip_before_filter :load_object

      before_filter :set_current_language

      before_filter :solution_article_enabled?

      before_filter :load_article, except: :suggested_articles

      before_filter :load_vote, only: [:thumbs_up, :thumbs_down]

      def suggested_articles
        load_articles
        log_and_render_404 unless @items
      end

      def thumbs_up
        update_votes(:thumbs_up, 1)
        head 204
      end

      def thumbs_down
        update_votes(:thumbs_down, 0)
        head 204
      end

      def hit
        @item.hit! if !agent? || current_account.solutions_agent_metrics_enabled?
        head 204
      end

      private

        def scoper
          current_account.solution_article_meta
                         .for_help_widget(@help_widget, current_user)
                         .published
        end

        def load_article
          meta_item = scoper.find_by_id(params[:id])
          @article = @item = meta_item.current_article if meta_item.present?
          log_and_render_404 if @item.blank?
        end

        def solution_article_enabled?
          return true if RELAXED_ACTIONS.include?(action_name.to_sym)

          render_request_error(:solution_article_not_enabled, 400, id: @widget_id) unless @help_widget.solution_articles_enabled?
        end

        def decorator_options
          [::Widget::Solutions::ArticleDecorator, {}]
        end

        def load_articles
          @items = scoper.order('solution_article_meta.hits desc').limit(5)
        end

        def agent?
          current_user && current_user.agent?
        end
    end
  end
end
