class Admin::GettingStartedController < Admin::AdminController
  
  before_filter :twitter_wrapper, :fb_client
  
  def index
    @email_configs = current_account.all_email_configs
    @email_config = current_account.primary_email_config
    @agent = current_account.agents.new       
    #@agent.user = User.new
    @agent.build_user
    @agent.user.avatar = Helpdesk::Attachment.new
    @agent.user.time_zone = current_account.time_zone
    @agent.user.language = current_portal.language
    @account = current_account
  end
    
  protected
  
    def twitter_wrapper
      @wrapper = TwitterWrapper.new @item, { :product => product, 
                                             :current_account => current_account,
                                             :callback_url => authdone_social_twitters_url }
    end

    def product
      @current_product ||= current_account.primary_email_config
    end
  
  
    def fb_client   
      @fb_client = FBClient.new @item, {  :current_account => current_account,
                                          :callback_url => authdone_social_facebook_url }
    end
  
end
