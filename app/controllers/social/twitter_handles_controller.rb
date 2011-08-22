class Social::TwitterHandlesController < ApplicationController
 
  before_filter :except => [:search, :create_twicket] do |c| 
    c.requires_permission :manage_users
  end
  
  before_filter :only => [:search, :create_twicket] do |c| 
    c.requires_permission :manage_forums
  end
  
  prepend_before_filter :load_product, :only => [ :signin, :authdone ]
  before_filter :load_main_product, :only => [:index]
  before_filter :build_item, :only => [:signin, :authdone]
  before_filter :load_item,  :only => [:tweet, :edit, :update, :search, :destroy]       
  before_filter :twitter_wrapper , :only => [:signin, :authdone, :index]
 
  def index
    request_token = @wrapper.request_tokens          
    session[:request_token] = request_token.token
    session[:request_secret] = request_token.secret
    store_location
    if @twitter_handle
      @twitter_user = Twitter.user(@twitter_handle.screen_name)
    end
  end
  
  def edit
    @twitter_user = Twitter.user(@item.screen_name)
    render :partial => "twitter_form"
  end 
  
  def signin
    request_token = @wrapper.request_tokens          
    session[:request_token] = request_token.token
    session[:request_secret] = request_token.secret    
    render :partial => "twitter_signin"   
  end

  def authdone
    add_to_db
    redirect_back_or_default redirect_url
  end
  
  def add_to_db
    begin      
      twitter_handle = @wrapper.auth( session[:request_token], session[:request_secret], params[:oauth_verifier] )
      if twitter_handle.save 
        flash.now[:notice] = t('twitter.success_signin')
      else
        flash.now[:notice] = t('twitter.user_exists')
      end
    rescue
      flash.now[:error] = t('twitter.not_authorized')
    end
  end
  
  def destroy
    @item.destroy   
    flash.now[:notice] = t('twitter.deleted')
    redirect_to :back
  end
  
  def show_time_lines
     @tweets = @wrapper.get_twitter 
  end

  def tweet
    begin
      @twitter = @wrapper.get_twitter
      @twitter.update params[:tweet]
      flash[:notice] = t('twitter.sent')
    rescue
      flash[:error] = t('twitter.error_sending')
    end
    redirect_to :action => :index
  end
  
 
  def update
    @item.search_keys = params[:search_keys_string].split(",")
    if @item.update_attributes(params[:social_twitter_handle])    
      flash.now[:notice] = I18n.t(:'flash.general.update.success', :human_name => human_name)
    else
      update_error
    end   
    respond_to do |format|
      format.html { redirect_to :back }
      format.js
    end
  end
  
  def new_search    
    @twitter_handles = scoper.find(:all, :include => :user)
    @twitter_search = current_account.twitter_search_keys.new
    render :partial => "new_search_key"   
  end
  
  def search
    @products    = current_account.email_configs.find(:all, :order => "primary_role desc")
    @search_keys = (@item.search_keys) || [] 
  end
  
  def feed
    @products   = current_account.email_configs.find(:all, :order => "primary_role desc")
    @twitter_accounts = current_account.twitter_handles
  end
  
  def create_twicket
    params[:helpdesk_tickets][:description] = Iconv.new('utf-8//IGNORE', "utf-8").iconv(params[:helpdesk_tickets][:description])
    @ticket = current_account.tickets.build(params[:helpdesk_tickets])
    @ticket.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter]
    res = Hash.new
    if @ticket.save
      res["success"] = true
      res["message"] = t('twitter.ticket_save')
      res["ticket_link"] = helpdesk_ticket_path(@ticket)
      render :json => ActiveSupport::JSON.encode(res)
    else
      res["success"] = false
      res["message"]= t('twitter.tkt_err_save')
      render :json => ActiveSupport::JSON.encode(res)
    end
  end
  
  def send_tweet
    reply_twitter = current_account.twitter_handles.find(params[:twitter_handle])
    unless reply_twitter.nil?
      @wrapper = TwitterWrapper.new reply_twitter
      twitter  = @wrapper.get_twitter
      twitter.update(params[:tweet][:body])
      flash.now[:notice] = "Successfully sent a tweet"
    end
    respond_to do |format|
      format.html { redirect_to :back }
      format.js
    end
  end 
  
  protected
  
    def load_main_product
      @current_product = current_account.primary_email_config
      @twitter_handle  = current_account.primary_email_config.twitter_handle
    end
  
    def twitter_wrapper   
      @wrapper = TwitterWrapper.new @item ,{ :product => @current_product, 
                                             :current_account => current_account,
                                             :callback_url => url_for(:action => 'authdone')}
    end
  
    def scoper
      @current_product
    end
  
    def load_product
      @current_product = current_account.all_email_configs.find(params[:product_id])
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
  
    def redirect_url
      if @item.product.primary_role?
        social_twitters_url
      else
        admin_products_url      
      end
    
    end

end
