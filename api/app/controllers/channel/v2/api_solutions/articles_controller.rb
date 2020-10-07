module Channel::V2::ApiSolutions
  class ArticlesController < ::ApiSolutions::ArticlesController
    include ChannelAuthentication
    include Solution::ArticlesVotingMethods
    skip_before_filter :check_privilege, :verify_authenticity_token, only: [:folder_articles, :search, :show, :index, :thumbs_up, :thumbs_down, :hit]
    before_filter :channel_client_authentication, only: [:folder_articles, :search, :show, :index,:thumbs_up, :thumbs_down, :hit]
    before_filter :validate_search_query_parameters, only: [:search]
    before_filter :validate_chat_query_parameters, only: [:folder_articles]
    
    def self.decorator_name
      ::Solutions::ArticleDecorator
    end

    def show
      @enrich_response = true
      super
    end

    def thumbs_up
      if load_user_and_vote
        set_interaction_source
        update_votes(:thumbs_up, 1)
        head 204
      else
        false
      end
    end

    def thumbs_down
      if load_user_and_vote
        set_interaction_source
        update_votes(:thumbs_down, 0)
        head 204
      else
        false
      end
    end

    def hit
      if load_user_and_vote
        if !agent? || current_account.solutions_agent_metrics_enabled?
          set_interaction_source
          @item.hit!
        end        
        head 204
      else
        false
      end
    end

    private

      def load_user_and_vote
        @article = @item
        head 405 and return false unless @article.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
        if params[:user_id].present?
          user = current_account.users.find_by_id(params[:user_id])
          log_and_render_404 and return false unless user
          @current_user = user.make_current
          load_vote unless [:hit].include?(action)
        end
        true
      end

      def set_interaction_source
        @article.set_interaction_source(params[:source_type].to_sym, params[:source_id], params[:platform])
      end

      def agent?
        current_user && current_user.agent?
      end
  end
end
