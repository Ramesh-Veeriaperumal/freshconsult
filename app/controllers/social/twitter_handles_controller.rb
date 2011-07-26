class Social::TwitterHandlesController < ApplicationController
 
  include HelpdeskControllerMethods 
  
  prepend_before_filter :load_product, :only => [:signin,:authdone]
  before_filter :build_item, :only => [:signin,:authdone]
  before_filter :load_item,  :only => [:tweet , :edit , :update, :search]       
  before_filter :twitter_wrapper , :except => [:create_twicket]
 

  def signin
    request_token = @wrapper.request_tokens          
    session[:request_token] = request_token.token
    session[:request_secret] = request_token.secret           
    render :partial => "twitter_signin"   
  end

  def authdone
    logger.debug "call back url called @time:: #{Time.now}"
    #begin      
      @wrapper.auth( session[:request_token] , session[:request_secret] , params[:oauth_verifier])    
      flash[:notice] = "Successfully signed in with Twitter."
    #rescue
    #  flash[:error] = 'You were not authorized by Twitter!'
    #end
    redirect_to admin_products_url
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
  
 
  def update
    logger.debug "Inside update :: #{params.inspect} and item :: #{@item.inspect}"
    @item.search_keys = params[:search_keys_string].split(",")
    if @item.update_attributes(params[:social_twitter_handle])    
      flash[:notice] = I18n.t(:'flash.general.update.success', :human_name => human_name)
       redirect_back_or_default admin_products_url
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
  
  def search
    @search_keys = (@item.search_keys) || [] 
  end
  
  def create_twicket
    @ticket = current_account.tickets.build(params[:helpdesk_tickets])
    @ticket.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter]
    res = Hash.new
    if @ticket.save
      res["success"] = true      
      res["message"]="Successfully saved the ticket from tweet"
      render :json => ActiveSupport::JSON.encode(res)
    else
      logger.debug "unable to save :: #{@ticket.errors.to_json}"
      res["success"] = false
      res["message"]="Unable to convert the tweet as ticket"
      render :json => ActiveSupport::JSON.encode(res)
    end
  end
  

  private
  #current_user is the user who's logged in
  
  def twitter_wrapper   
    @wrapper = TwitterWrapper.new @item ,{ :product => @current_product, :current_account => current_account}
  end
  
  def scoper
    @current_product
  end
  
  def load_product
    @current_product = current_account.products.find(params[:product_id])
  end  
  
  def build_item
    @item = scoper.build_twitter_handle
  end
  
  def load_item
    @item = current_account.twitter_handles.find(params[:id]) 
  end

  def human_name
    'Twitter'
  end

end
