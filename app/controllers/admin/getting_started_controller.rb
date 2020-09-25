class Admin::GettingStartedController < Admin::AdminController
  
  before_filter :set_session_state ,:fb_client

  helper Admin::GettingStartedHelper
  include Admin::Social::FacebookAuthHelper
  
  VALID_COLOR_REGEX = /^#(?:[0-9a-fA-F]{3}){1,2}$/

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
    render :layout => false
  end
  
  def delete_logo
  	 current_account.main_portal.logo.destroy
     current_account.main_portal.save
 	   render :text => "success"
  end

  def rebrand    
    pref = params[:account][:main_portal_attributes][:preferences]
    pref.each do |key,value|        
        error(key) unless valid_color_code(value)
        break unless @error.blank?
    end

    current_portal.update_attributes(params[:account][:main_portal_attributes]) if @error.blank?
    current_portal.save
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

    def fb_client
      callback_url = "#{AppConfig['integrations_url'][Rails.env]}/facebook/page/callback"
      @fb_client = make_fb_client(callback_url, admin_social_facebook_streams_url)
    end

end
