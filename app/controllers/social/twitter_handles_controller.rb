class Social::TwitterHandlesController < ApplicationController
  
  require 'twitter'
 
  before_filter :except => [:search, :create_twicket] do |c| 
    c.requires_permission :manage_users
  end
  
  before_filter :only => [:search, :create_twicket] do |c| 
    c.requires_permission :manage_forums
  end
  
  prepend_before_filter :load_product, :only => [:signin,:authdone]
  before_filter :load_main_product, :only => [:index]
  before_filter :build_item, :only => [:signin, :authdone]
  before_filter :load_item,  :only => [:tweet, :edit, :update, :search, :destroy]       
  before_filter :twitter_wrapper , :only => [:signin,:authdone]
 

  def signin
    request_token = @wrapper.request_tokens          
    session[:request_token] = request_token.token
    session[:request_secret] = request_token.secret           
    render :partial => "twitter_signin"   
  end

  def authdone
    add_to_db
    redirect_to redirect_url
  end
  
  def add_to_db
    begin      
      twitter_handle = @wrapper.auth( session[:request_token] , session[:request_secret] , params[:oauth_verifier]) 
      if twitter_handle.save 
        flash[:notice] = t('twitter.success_signin')
      else
        flash[:notice] = t('twitter.user_exists')
      end
    rescue
      flash[:error] = t('twitter.not_authorized')
    end
  end
  
  def destroy
    @item.destroy   
    flash[:notice] = t('twitter.deleted')
    redirect_back_or_default redirect_url
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
      flash[:notice] = I18n.t(:'flash.general.update.success', :human_name => human_name)
       redirect_back_or_default redirect_url
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
    @products   = current_account.email_configs.find(:all, :order => "primary_role desc")
    @search_keys = (@item.search_keys) || [] 
  end
  
  def tweet_feed
    @products   = current_account.email_configs.find(:all, :order => "primary_role desc")
  end
  
  def create_ticket_from_tweet
    @ticket = current_account.tickets.build(params[:helpdesk_tickets])
    @ticket.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter]
    @ticket
  end
  
  def get_twitter_user(screen_name)
    user = current_account.all_users.find_by_twitter_id(screen_name)
    unless user
      user = current_account.contacts.new
      user.signup!({:user => {:twitter_id => screen_name, :name => screen_name, 
                    :active => true,
                    :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}})
      end
     user 
  end
  
  def create_note_from_tweet(in_reply_to_status_id)
    tweet = current_account.tweets.find_by_tweet_id(in_reply_to_status_id)
    user = get_twitter_user(params[:helpdesk_tickets][:twitter_id])
    
    unless tweet.nil?  
      @ticket = tweet.tweetable.notable if  tweet.tweetable_type.eql?('Helpdesk::Note')
      @ticket = tweet.tweetable if  tweet.tweetable_type.eql?('Helpdesk::Ticket')
    end
    
    unless @ticket.blank?
      @note = @ticket.notes.build(
        :body => params[:helpdesk_tickets][:description],
        :private => true ,
        :incoming => true,
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter],
        :account_id => current_account.id,
        :user_id => user.id ,
        :tweet_attributes => {:tweet_id => params[:helpdesk_tickets][:tweet_attributes][:tweet_id], 
                                          :account_id => current_account.id}
       )
       @note
    else
      create_ticket_from_tweet 
    end
  end
  
  def create_twicket
    in_reply_to_status_id = nil
    sandbox do 
      in_reply_to_status_id = Twitter.status(params[:helpdesk_tickets][:tweet_attributes][:tweet_id]).in_reply_to_status_id_str
    end
    if in_reply_to_status_id.blank?
      @item = create_ticket_from_tweet
    else
      @item = create_note_from_tweet(in_reply_to_status_id)
    end
    res = Hash.new
    if @item.save
      res["success"] = true      
      res["message"]= t('twitter.ticket_save')
      render :json => ActiveSupport::JSON.encode(res)
    else
      res["success"] = false
      res["message"]= t('twitter.tkt_err_save')
      render :json => ActiveSupport::JSON.encode(res)
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
  
  def sandbox
      begin
        yield
      rescue Errno::ECONNRESET => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Timeout::Error => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue EOFError => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Errno::ETIMEDOUT => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue OpenSSL::SSL::SSLError => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue SystemStackError => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue 
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in twitter!"
      end
    end

end
