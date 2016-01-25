class Mobihelp::ArticlesController < MobihelpController

  include Solution::ArticlesVotingMethods
  include Mobihelp::MobihelpHelperMethods

  before_filter :mobihelp_user_login
  before_filter :validate_user
  before_filter :load_article
  before_filter :load_vote

  private

    def load_article
      @article = current_account.solution_articles.find_by_id(params[:id])
    end

    def validate_user
      User.current = @current_user = nil unless valid_user?
    end
end
