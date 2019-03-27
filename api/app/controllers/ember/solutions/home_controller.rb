module Ember
  module Solutions
    class HomeController < ApiApplicationController
      include HelperConcern
      include Cache::Memcache::Portal

      def summary
        return unless validate_query_params
        return unless validate_delegator(nil, portal_id: params[:portal_id])
        @items = current_account.solution_category_meta.joins(:portal_solution_categories).where('solution_category_meta.is_default = ? AND portal_solution_categories.portal_id = ?', false, params[:portal_id]).order('portal_solution_categories.position').preload([:portal_solution_categories, :primary_category, solution_folder_meta: [:primary_folder, :solution_article_meta]])
        response.api_root_key = :categories
      end

      def quick_views
        return unless validate_query_params
        return unless validate_delegator(nil, portal_id: params[:portal_id])
        @categories = fetch_categories(params[:portal_id])
        @articles = fetch_articles
        @drafts =  fetch_drafts
        @my_drafts = @drafts.empty? ? [] : @drafts.where(user_id: current_user.id)
        @published_articles = fetch_published_articles
        @all_feedback = current_account.article_tickets.where(article_id: get_article_ids(@articles)).preload(:ticketable).select { |article| !article.ticketable.spam_or_deleted? }
        @my_feedback = current_account.article_tickets.where(article_id: get_article_ids(@articles.select{ |article| article.user_id == current_user.id })).preload(:ticketable).select { |article| !article.ticketable.spam_or_deleted? }
        @orphan_categories = fetch_unassociated_categories_from_cache || []
        response.api_root_key = :quick_views
      end

      private

        def fetch_categories(portal_id)
          @category_meta = current_account.portals.where(id: portal_id).first.solution_categories_from_cache
          current_account.solution_categories.where(parent_id: @category_meta.map(&:id), language_id: (Language.current? ? Language.current.id : Language.for_current_account.id))
        end

        def fetch_articles
          return [] if @category_meta.empty?
          article_meta = []
          @category_meta.each do |categ_meta|
            article_meta << categ_meta.solution_article_meta.preload(&:current_article)
          end
          article_meta.flatten!
          current_account.solution_articles.select([:id,:user_id,:status]).where(parent_id: article_meta.map(&:id), language_id: (Language.current? ? Language.current.id : Language.for_current_account.id))
        end

        def fetch_drafts
          return [] if @articles.empty?
          article_ids = get_article_ids(@articles)
          current_account.solution_drafts.select([:id, :user_id]).where(article_id: article_ids)
        end

        def get_article_ids(articles)
          articles.map(&:id)
        end

        def fetch_published_articles
          return [] if @articles.empty?
          @articles.where(status: Solution::Constants::STATUS_KEYS_BY_TOKEN[:published])
        end

        def fetch_unassociated_categories_from_cache
          CustomMemcacheKeys.fetch(CustomMemcacheKeys::UNASSOCIATED_CATEGORIES % {account_id: current_account.id}, "Unassociated categories for #{current_account.id}") do
            associated_category_ids = current_account.portal_solution_categories.map(&:solution_category_meta_id).uniq
            current_account.solution_category_meta.select(:id).where('id NOT IN (?)', associated_category_ids)
          end
        end

        def constants_class
          'Solutions::HomeConstants'.freeze
        end
    end
  end
end
