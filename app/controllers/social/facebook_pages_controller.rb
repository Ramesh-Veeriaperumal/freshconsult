class Social::FacebookPagesController < ApplicationController
  
   before_filter :except => [:event_listener] do |c| 
    c.requires_permission :manage_users
  end
  
  before_filter :fb_client , :only => [:signin, :authdone, :index]
  before_filter :build_item, :only => [:signin, :authdone]
  before_filter :load_item,  :only => [:edit, :update, :destroy]  
  
  def index
    @fb_pages = scoper
    
  end

  def edit
    
  end
  
  def signin
    #request_token = @fb_client.request_tokens          
    #session[:request_token] = request_token.token
    #session[:request_secret] = request_token.secret    
  end
  
  def event_listener
    logger.debug "verify_token has been called..meet challenge will be executed :: with params:: #{params.inspect}"
    verify_token = "freshdesktoken"
    return Koala::Facebook::RealtimeUpdates.meet_challenge(params, verify_token)
  end
  
   def authdone
     add_to_db
     @fb_client.subscribe(url_for(:action => 'event_listener'))
     redirect_to :action =>:index
    #add_to_db
    #redirect_to redirect_url
  end
  
  def add_to_db
    begin      
      fb_pages = @fb_client.auth(params[:code] )
      if scoper.create(fb_pages)
       # flash[:notice] = t('twitter.success_signin', :twitter_screen_name => twitter_handle.screen_name, :helpdesk => twitter_handle.product.name)
      else
       # flash[:notice] = t('twitter.user_exists')
      end
    rescue
      flash[:error] = t('twitter.not_authorized')
    end
  end
  
  def destroy
    @item.destroy   
    flash[:notice] = t('facebook.deleted', :facebook_page => @item.page_name)
    redirect_back_or_default social_facebook_url 
  end
  
  def comment_on_post
    begin
      @facebook = @fb_client
      @facebook.put_comment params[:tweet]
      flash[:notice] = t('twitter.sent')
    rescue
      flash[:error] = t('twitter.error_sending')
    end
    redirect_to :action => :index
  end
  
 
  def update
    
    if @item.update_attributes(params[:social_facebook_page])    
      flash[:notice] = I18n.t(:'flash.facebook.updated')
    else
      update_error
    end   
    respond_to do |format|
      format.html { redirect_to redirect_url }
      format.js
    end
  end
  
  
  
  
  protected
  
   def scoper
      current_account.facebook_pages
    end
  
   def fb_client   
     @fb_client = FBClient.new @item ,{   :current_account => current_account,
                                          :callback_url => url_for(:action => 'authdone')}
    end
    
   def build_item
      @item = scoper.build
    end
  
    def load_item
      @item = current_account.facebook_pages.find(params[:id]) 
    end

    def human_name
      'Facebook'
   end
  
  def redirect_url
      edit_social_facebook_url(@item)
  end
  
  

end
