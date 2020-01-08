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

        @categories = fetch_categories(params[:portal_id])
        @articles = fetch_articles
        @drafts =  fetch_drafts
        @approvals = fetch_approvals
        @my_drafts = @drafts.empty? ? [] : @drafts.where(user_id: current_user.id)
        @my_drafts =  fetch_my_drafts if Account.current.article_approval_workflow_enabled?
        @published_articles = fetch_published_articles
        @all_feedback = current_account.article_tickets.where(article_id: get_article_ids(@articles), ticketable_type: 'Helpdesk::Ticket').preload(:ticketable).reject { |article_ticket| article_ticket.ticketable.spam_or_deleted? }
        @my_feedback = current_account.article_tickets.where(article_id: get_article_ids(@articles.select { |article| article.user_id == current_user.id }), ticketable_type: 'Helpdesk::Ticket').preload(:ticketable).reject { |article| article.ticketable.spam_or_deleted? }
        @orphan_categories = fetch_unassociated_categories(@lang_id)
        @secondary_language = secondary_language?
        if @secondary_language
          @outdated_articles = @articles.select { |article| article.outdated == true }.size
          @not_translated_articles = @article_meta.size - @articles.size
        end
        @articles_with_approval_status = fetch_articles_by_approval_status if current_account.article_approval_workflow_enabled?
        response.api_root_key = :quick_views
      end

      private

        def fetch_categories(portal_id)
          if portal_id.present?
            @category_meta = current_account.portals.find_by_id(portal_id).public_category_meta.order('portal_solution_categories.position').all
          else
            @category_meta = current_account.public_category_meta
          end
          portal_categories = current_account.solution_categories.where(parent_id: @category_meta.map(&:id), language_id: @lang_id)
          @category_meta += [current_account.solution_category_meta.where(is_default: true).first]
          portal_categories
        end

        def fetch_articles
          @article_meta = []
          return [] if @category_meta.empty?

          @category_meta.each do |categ_meta|
            @article_meta << categ_meta.solution_article_meta.preload(&:current_article)
          end
          @article_meta.flatten!
          current_account.solution_articles.select([:id, :user_id, :status, :outdated]).where(parent_id: @article_meta.map(&:id), language_id: @lang_id)
        end

        def fetch_drafts
          return [] if @articles.empty?

          article_ids = get_article_ids(@articles)
          current_account.solution_drafts.select([:id, :user_id]).where(article_id: article_ids)
        end

        def fetch_approvals
          return [] if @articles.empty?
          article_ids = get_article_ids(@articles)
          current_account.helpdesk_approvals.select([:id, :user_id]).where(approvable_id: article_ids, approvable_type: 'Solution::Article')
        end

        def fetch_my_drafts
           return [] if @my_drafts.empty?
           join_condition = format(%(LEFT JOIN helpdesk_approvals ON solution_drafts.article_id = helpdesk_approvals.approvable_id AND helpdesk_approvals.account_id = %{account_id}), account_id: Account.current.id)
           @my_drafts.joins(join_condition).where("helpdesk_approvals.id is NULL")
        end

        def fetch_articles_by_approval_status
          current_account.helpdesk_approvals.where(approvable_id: get_article_ids(@articles), approvable_type: 'Solution::Article').group(:approval_status).count
        end

        def get_article_ids(articles)
          articles.map(&:id)
        end

        def fetch_published_articles
          return [] if @articles.empty?

          @articles.where(status: Solution::Constants::STATUS_KEYS_BY_TOKEN[:published])
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
