module Ember
  module Solutions
    class HomeController < ApiApplicationController
      include HelperConcern
      include Cache::Memcache::Portal
      include SolutionConcern

      def summary
        return unless validate_language
        return unless validate_query_params
        return unless validate_delegator(nil, portal_id: params[:portal_id])
        portal = current_account.portals.where(id: params[:portal_id]).first
        @items = portal.solution_categories.joins(:solution_category_meta).where('solution_category_meta.is_default = ? AND language_id = ?', false, @lang_id).preload(preload_options)
        response.api_root_key = :categories
      end

      def quick_views
        return unless validate_language
        return unless validate_query_params
        return unless validate_delegator(nil, portal_id: params[:portal_id])

        pl_filter = Solution::PortalLanguageFilter.new(params[:portal_id], @lang_id)
        quick_view_counts_with_filter(pl_filter)
        @templates = pl_filter.active_templates if current_account.solutions_templates_enabled?
        response.api_root_key = :quick_views
      end

      private

        def quick_view_counts_with_filter(pl_filter)
          @categories_cnt = pl_filter.categories.count
          @folders_cnt = @categories_cnt > 0 ? pl_filter.folders.count : 0
          @articles_cnt = @categories_cnt > 0 ? pl_filter.articles.count : 0
          all_drafts_cnt = @articles_cnt > 0 ? pl_filter.drafts.count : 0
          all_approvals_cnt = all_drafts_cnt > 0 ? pl_filter.approvals.count : 0
          @drafts_cnt = all_drafts_cnt - all_approvals_cnt
          @my_drafts_cnt = @drafts_cnt > 0 ? pl_filter.my_drafts.count : 0
          @published_articles_cnt = @articles_cnt > 0 ? pl_filter.published_articles.count : 0
          @all_feedback_cnt = pl_filter.all_feedback.count
          @my_feedback_cnt = pl_filter.my_feedback.count
          # @orphan_categories_cnt = pl_filter.unassociated_categories.count
          # Using same logic for unassociated_categories, since it is using the cache and expected to be small in number
          @orphan_categories = fetch_unassociated_categories(@lang_id)
          @secondary_language = secondary_language?
          if @secondary_language
            @outdated_articles = @articles_cnt > 0 ? pl_filter.outdated_articles.count : 0
            @not_translated_articles = pl_filter.article_meta.count - @articles_cnt
          end
          @articles_with_approval_status = pl_filter.articles_count_by_approval_status if current_account.article_approval_workflow_enabled?
        end

        def constants_class
          'Solutions::HomeConstants'.freeze
        end

        def preload_options
          [solution_category_meta: [:portal_solution_categories, solution_folder_meta: [:"#{@lang_code}_folder", { solution_article_meta: :"#{@lang_code}_article" }]]]
        end
    end
  end
end
