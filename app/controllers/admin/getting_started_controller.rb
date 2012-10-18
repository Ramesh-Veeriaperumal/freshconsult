class Admin::GettingStartedController < Admin::AdminController
  
  before_filter :build_twitter_item, :twitter_wrapper, :build_fb_item, :fb_client

  helper Admin::GettingStartedHelper
  
  VALID_COLOR_REGEX = /^#(?:[0-9a-fA-F]{3}){1,2}$/

  def index
    request_token = @wrapper.request_tokens   
    @auth_redirect_url = request_token.authorize_url
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
    render :layout => false
  end
  
  def delete_logo
  	 current_account.main_portal.logo.destroy
 	   render :text => "success"
  end

  def rebrand    
    pref = params[:account][:main_portal_attributes][:preferences]
    pref.each do |key,value|        
        error(key) unless valid_color_code(value)
        break unless @error.blank?
    end

    current_portal.update_attributes(params[:account][:main_portal_attributes]) if @error.blank?
    redirect_params = {:activeSlide => "3"}
    redirect_params[:error] = @error unless @error.blank?
    redirect_to admin_getting_started_index_path(redirect_params) if params["rebrand_from_ie"]=="true"
  end
    
  protected
    
    def error(color_title)
          @error = I18n.t('admin.getting_started.index.rebrand_header_invalid') if(color_title.eql?("header_color"))
          @error = I18n.t('admin.getting_started.index.rebrand_tab_invalid') if(color_title.eql?("tab_color"))
          @error = I18n.t('admin.getting_started.index.rebrand_bg_invalid') if(color_title.eql?("bg_color"))          
    end

    def valid_color_code(color)      
      (color =~ VALID_COLOR_REGEX) ? true : false
    end

    def twitter_wrapper
      @wrapper = TwitterWrapper.new @twitter_item, {:current_account => current_account,
                                             :callback_url => authdone_social_twitters_url }
    end
  
    def build_twitter_item
      @twitter_item = current_account.twitter_handles.build
    end
    
    
    def fb_client   
      @fb_client = FBClient.new @fb_item, {  :current_account => current_account,
                                          :callback_url => authdone_social_facebook_url }
    end
    
    def build_fb_item
      @fb_item = current_account.facebook_pages.build
    end
  
end
