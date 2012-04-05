class Admin::GettingStartedController < Admin::AdminController
  
  before_filter :build_twitter_item, :twitter_wrapper, :build_fb_item, :fb_client
  
  def index
    request_token = @wrapper.request_tokens          
    session[:request_token] = request_token.token
    session[:request_secret] = request_token.secret    
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
  
  def delete_logo
  	 current_account.main_portal.logo.destroy
 	   render :text => "success"
  end
    
  protected
  
    def twitter_wrapper
      @wrapper = TwitterWrapper.new @twitter_item, { :product => product, 
                                             :current_account => current_account,
                                             :callback_url => authdone_social_twitters_url }
    end

    def product
      current_account.primary_email_config
    end
  
    def build_twitter_item
      @twitter_item = product.twitter_handles.build
    end
    
    
    def fb_client   
      @fb_client = FBClient.new @fb_item, {  :current_account => current_account,
                                          :callback_url => authdone_social_facebook_url }
    end
    
    def build_fb_item
      @fb_item = current_account.facebook_pages.build
    end
  
end
