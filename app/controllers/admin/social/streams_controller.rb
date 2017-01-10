class Admin::Social::StreamsController < Admin::AdminController

  include Social::Twitter::Constants
  
  before_filter :twitter_wrapper, :only => [:index, :authorize_url]

  def index
    @add_new_handle    = current_account.add_twitter_handle?
    @add_new_stream    = current_account.add_custom_twitter_stream?
    @auth_redirect_url = twitter_authorize_url
    @twitter_handles   = current_account.twitter_handles
    @twitter_streams   = current_account.all_twitter_streams
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
  
  def stream_accessible_params(social_stream)
    accessible_attributes = {}
    visible_group_ids = params[:visible_to]
    if visible_group_ids.include?(Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all].to_s)
      accessible_attributes[:access_type] = Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
      accessible_attributes[:group_ids] = []
    else
      accessible_attributes[:access_type] = Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
      accessible_attributes[:group_ids] = visible_group_ids
    end
    accessible_attributes[:id] = social_stream.accessible.id if social_stream
    accessible_attributes
  end

  def twitter_authorize_url
    request_token            = @wrapper.request_tokens
    session[:request_token]  = request_token.token
    session[:request_secret] = request_token.secret
    request_token.authorize_url
  rescue Exception => e
    Rails.logger.error e
    Rails.logger.error e.backtrace
    NewRelic::Agent.notice_error(e)
    nil
  end
  
  def update_dm_rule(social_account)
    dm_stream = social_account.dm_stream
    unless dm_stream.ticket_rules.empty?
      group_id = params[:dm_rule][:group_assigned].to_i
      dm_stream.update_ticket_action_data(social_account.product_id, group_id) 
    end
  end
  
end
