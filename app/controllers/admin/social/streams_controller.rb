class Admin::Social::StreamsController < Admin::AdminController

  include Social::Twitter::Constants
  
  before_filter { |c| c.requires_feature :twitter }
  before_filter :twitter_wrapper, :only => [:index, :authorize_url]

  def index
    @auth_redirect_url = twitter_authorize_url
    @twitter_handles   = current_account.twitter_handles
    @twitter_streams   = current_account.all_social_streams
  end
  
  def authorize_url
    redirect_to twitter_authorize_url
  end

  private
  def twitter_wrapper
    @wrapper = TwitterWrapper.new(nil, {
                                    :current_account => current_account,
                                    :callback_url => authdone_admin_social_twitters_url
    })
  end

  def twitter_authorize_url
    request_token            = @wrapper.request_tokens
    session[:request_token]  = request_token.token
    session[:request_secret] = request_token.secret
    request_token.authorize_url
  end
  
end
