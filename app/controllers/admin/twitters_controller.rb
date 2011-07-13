class Admin::TwittersController < ApplicationController
 
  include HelpdeskControllerMethods 
  
 before_filter :build_item,  :only => [:signin, :authdone ]
 before_filter :load_item,  :only => [:tweet , :edit , :update]       
 before_filter :twitter_wrapper 
 
  

  def index
    #begin
      @twitter_users = scoper.find(:all, :include => :user)   
      @search_keys = current_account.twitter_search_keys.all
    #rescue
     # @twitter = nil
    #end
  end

  def signin   
      request_token = @wrapper.request_tokens          
      session[:request_token] = request_token.token
      session[:request_secret] = request_token.secret           
      render :partial => "twitter_signin"   
  end

  def authdone
    logger.debug "call back url called @time:: #{Time.now}"
    begin      
      @wrapper.auth( session[:request_token] , session[:request_secret] , params[:oauth_verifier])    
      flash[:notice] = "Successfully signed in with Twitter."
    rescue
      flash[:error] = 'You were not authorized by Twitter!'
    end
    redirect_to :action => :index
  end
  
  def show_time_lines
     @tweets = @wrapper.get_twitter 
     logger.debug "The time line is :: #{@tweets.inspect}"
  end

  def tweet
    begin
      @twitter = @wrapper.get_twitter
      @twitter.update params[:tweet]
      flash[:notice] = "Tweet successfully sent!"
    rescue
      flash[:error] = "Error sending the tweet! Twitter might be unstable. Please try again."
    end
    redirect_to :action => :index
  end
  
  def edit
    @groups = current_account.groups
  end
  
  def update
    logger.debug "Inside update :: #{params.inspect} and item :: #{@item.inspect}"
    if @item.update_attributes(params[:twitter])    
      flash[:notice] = I18n.t(:'flash.general.update.success', :human_name => human_name)
       redirect_back_or_default admin_twitters_url
    else
      update_error
      render :action => 'edit'
    end   
  end
  
  def new_search    
    @twitter_handles = scoper.find(:all, :include => :user)
    @twitter_search = current_account.twitter_search_keys.new
    render :partial => "new_search_key"   
  end
  
  def add_search_key
     logger.debug "add search key #{params.inspect} "
    @twitter_search = current_account.twitter_search_keys.new(params[:twitter_search])
    if @twitter_search.save  
      flash[:notice] = I18n.t(:'flash.general.update.success', :human_name => human_name)      
    else
       flash[:notice] = "Unable to save the search key"
    end 
     redirect_back_or_default admin_twitters_url
  end
  
  def edit_search
    @twitter_search = current_account.twitter_search_keys.find(params[:id])
    @twitter_handles = scoper.find(:all, :include => :user)
    render :partial => "edit_search_key"   
  end
  
  def update_search_key
    logger.debug "update_search_key:: #{params.inspect} "
    @twitter_search = current_account.twitter_search_keys.find(params[:twitter][:id])
    if @twitter_search.update_attributes(params[:twitter_search])
      flash[:notice] = I18n.t(:'flash.general.update.success', :human_name => human_name) 
    else
      flash[:notice] = "Unable to save the search key"
    end
     redirect_back_or_default admin_twitters_url
  end
  
  def delete_search_key
     @twitter_search = current_account.twitter_search_keys.find(params[:id])
     @twitter_search.destroy
     redirect_back_or_default admin_twitters_url
  end

  private
  #current_user is the user who's logged in
  
  def twitter_wrapper   
    logger.debug "loading.....twitter_wrapper........with item..:#{@item} "
    @wrapper = TwitterWrapper.new @item ,current_account
  end
  
  def scoper
    current_account.twitter_handles
  end

  def cname
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end
  
  def update_error
    @groups = current_account.groups
  end
  
   def human_name
      "Twitter"
   end
  


end
