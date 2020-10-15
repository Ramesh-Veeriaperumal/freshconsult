class Social::TwitterHandlesController < ApplicationController

  include ErrorHandle

  before_filter { access_denied unless current_account.basic_twitter_enabled? }

  prepend_before_filter :load_product, :only => [:signin, :authdone]
  before_filter :build_item, :only => [:signin, :authdone]
  before_filter :load_item,  :only => [:tweet, :edit, :update, :destroy]
  before_filter :welcome_page_redirect, :only => [:index, :feed]
  before_filter :twitter_wrapper, :only => [:signin, :authdone, :index]
  before_filter :check_if_handles_exist, :only => [:feed]

  def check_if_handles_exist
    if current_account.twitter_handles.blank?
      flash[:notice] = t('no_twitter_handle')
      redirect_to social_twitters_url
    end
  end

  def twitter_search
    twt_handle = current_account.twitter_handles.first if params[:handle] == "0"
    twt_handle = current_account.twitter_handles.find(params[:handle]) unless twt_handle
    if twt_handle
      wrapper = TwitterWrapper.new twt_handle
      begin
        twitter = wrapper.get_twitter
        if params[:max_id]
          response = twitter.search(params[:q], {:max_id => params[:max_id], :count => params[:count].to_i}).attrs
        elsif params[:since_id]
          response = twitter.search(params[:q], {:since_id => params[:since_id], :count => params[:count].to_i}).attrs
        else
          response = twitter.search(params[:q], {:count => params[:count].to_i}).attrs
        end
      rescue Twitter::Error::TooManyRequests => e
        response = { :err => e.to_s }
        NewRelic::Agent.notice_error(e)
      end
    end
    render :json => response.to_json, :callback => params[:callback]
  end

  def tweet_exists
    converted_tweets = current_account.tweets.where(tweet_id: params[:tweet_ids].split(",")).includes(:tweetable).to_a
    @tweet_tkt_hsh = {}
    converted_tweets.each do |tweet|
      @tweet_tkt_hsh.store(tweet.tweet_id,tweet.get_ticket.display_id)
    end

    respond_to do |format|
      format.json  { render :json => @tweet_tkt_hsh.to_json }
    end

  end

  def index
    returned_val = sandbox(0) {
      request_token = @wrapper.request_tokens
      session[:request_token] = request_token.token
      session[:request_secret] = request_token.secret
      @auth_redirect_url = request_token.authorize_url
      @twitter_handles = all_twitters
    }

    if returned_val == 0
      flash[:error] = t('twitter.not_authorized')
      redirect_to admin_home_index_url
    end
  end

  def signin
    request_token = @wrapper.request_tokens
    session[:request_token] = request_token.token
    session[:request_secret] = request_token.secret
  end

  def authdone
    add_to_db
  end

  def add_to_db
    returned_value = sandbox(0) {
      twitter_handle = @wrapper.auth( session[:request_token], session[:request_secret], params[:oauth_verifier] )
      handle = all_twitters.find_by_twitter_user_id(twitter_handle[:twitter_user_id])
      unless handle.nil?
        handle.attributes = {
          :access_token  => twitter_handle.access_token,
          :access_secret => twitter_handle.access_secret,
          :last_dm_id    => nil, :last_mention_id => nil,
          :state         => Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:active],
          :last_error    => nil
        }
        handle.save
        handle.construct_avatar unless handle.avatar
        redirect_to edit_social_twitter_url(handle)
      else
        twitter_handle.save
        portal_name    = twitter_handle.product ? twitter_handle.product.name : current_account.portal_name
        flash[:notice] = t('twitter.success_signin', :twitter_screen_name => twitter_handle.screen_name, :helpdesk => portal_name)
        redirect_to edit_social_twitter_url(twitter_handle)
      end
    }
    if returned_value == 0
      flash[:notice] = t('twitter.not_authorized')
      redirect_to social_twitters_url
    end
  end

  def destroy
    flash[:notice] = t('twitter.deleted', :twitter_screen_name => @item.screen_name)
    @item.destroy
    redirect_back_or_default social_twitters_url
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
    params[:social_twitter_handle][:search_keys] = [] if(params[:social_twitter_handle][:search_keys].blank?)

    if @item.update_attributes(params[:social_twitter_handle])
      @item.update_ticket_rules
      flash[:notice] = I18n.t(:'flash.twitter.updated')
      redirect_to social_twitters_url
    else
      flash.now[:notice] = 'We encountered and error while saving the twitter handle'
      render 'edit'
    end
  end


  def feed
    @selected_tab = :social
    @twitter_accounts = current_account.twitter_handles
  end

  def create_ticket_from_tweet
    user    = get_twitter_user(params[:helpdesk_tickets][:twitter_id],params[:profile_image][:url])
    @ticket = current_account.tickets.build(params[:helpdesk_tickets])
    @ticket.source = Helpdesk::Source::TWITTER
    @ticket
  end

  def get_twitter_user(screen_name, profile_image_url)
    user = current_account.all_users.find_by_twitter_id(screen_name)
    unless user
      user = current_account.contacts.new
      user.signup!({:user => {
                      :twitter_id     => screen_name,
                      :name           => screen_name,
                      :active         => true,
                      :helpdesk_agent => false
      }})
    end
    if user.avatar.nil? && !profile_image_url.nil?
      args = {
        :account_id      => current_account.id,
        :twitter_user_id => user.id,
        :prof_img_url    => profile_image_url
      }
      Social::UploadAvatar.perform_async(args)
    end
    user
  end

  def create_note_from_tweet(in_reply_to_status_id)
    tweet = current_account.tweets.find_by_tweet_id(in_reply_to_status_id)
    user  = get_twitter_user(params[:helpdesk_tickets][:twitter_id],params[:profile_image][:url])

    unless tweet.nil?
      @ticket = tweet.get_ticket
    end

    unless @ticket.blank?
      @note = @ticket.notes.build(
        :note_body_attributes => {
          :body => params[:helpdesk_tickets][:ticket_body_attributes][:description]
        },
        :private          => true,
        :incoming         => true,
        :source           => Helpdesk::Source::TWITTER,
        :account_id       => current_account.id,
        :user_id          => user.id,
        :tweet_attributes => {
          :tweet_id          => params[:helpdesk_tickets][:tweet_attributes][:tweet_id],
          :twitter_handle_id => tweet.twitter_handle_id
        }
      )
      @note
    else
      create_ticket_from_tweet
    end
  end

  def create_twicket
    in_reply_to_status_id = nil

    return_value = sandbox(0) {
      twt_handle = current_account.twitter_handles.find(params[:helpdesk_tickets][:tweet_attributes][:twitter_handle_id])
      if twt_handle
        wrapper   = TwitterWrapper.new twt_handle
        twitter   = wrapper.get_twitter
        stream_id = twt_handle.default_stream_id
        params[:helpdesk_tickets][:tweet_attributes].merge!(:stream_id => stream_id)
        in_reply_to_status_id = twitter.status(params[:helpdesk_tickets][:tweet_attributes][:tweet_id]).in_reply_to_status_id
      end
    }

    if return_value == 0
      flash.now[:notice] = "Something wrong with the twitter API"
      return render :partial => "create_twicket"
    end

    if in_reply_to_status_id.blank?
      @item = create_ticket_from_tweet
    else
      @item = create_note_from_tweet(in_reply_to_status_id)
    end
    @saved = @item.instance_of?(Helpdesk::Note) ? @item.save_note : @item.save_ticket
    if @saved
      flash.now[:notice] = t('twitter.ticket_save')
    else
      flash.now[:notice] = t('twitter.tkt_err_save')
    end
    render :partial => "create_twicket"
  end

  def send_tweet
    reply_twitter = current_account.twitter_handles.find(params[:twitter_handle])

    begin
      unless reply_twitter.nil?
        @wrapper = TwitterWrapper.new reply_twitter
        twitter  = @wrapper.get_twitter
        reply_tweet_body = params[:tweet][:body].strip
        in_reply_to = params[:tweet][:in_reply_to]
        reply_tweet = twitter.update(reply_tweet_body, {:in_reply_to_status_id => in_reply_to})
        flash.now[:notice] = "Successfully sent a tweet"
      end
    rescue Twitter::Error::Forbidden => e
      NewRelic::Agent.notice_error(e)
      flash.now[:notice] = t('twitter.duplicate_status')
    end
    respond_to do |format|
      format.html { redirect_to :back }
      format.js
    end
  end


  protected

  def update_ticket_action_data
    dm_rule = @item.dm_stream.ticket_rules.first
    dm_rule.update_attributes(
      :action_data => {
        :product_id => @item.product_id,
        :group_id   => nil
    }) unless dm_rule.nil?
    default_rule = @item.default_stream.ticket_rules.first
    default_rule.update_attributes(
      :action_data => {
        :product_id => @item.product_id,
        :group_id   => nil
    }) unless default_rule.nil?
  end

  def twitter_wrapper
    @wrapper = TwitterWrapper.new(@item ,{
                                    :product         => @current_product,
                                    :current_account => current_account,
                                    :callback_url    => url_for(:action => 'authdone')
    })
  end

  def scoper
    @current_product ? @current_product.twitter_handles : current_account.twitter_handles
  end

  def all_twitters
    current_account.twitter_handles
  end

  def load_product
    @current_product = current_account.products.find(params[:product_id]) if params[:product_id]
  end

  def build_item
    @item = scoper.build
  end

  def load_item
    @item = current_account.twitter_handles.find(params[:id])
  end

  def human_name
    'Twitter'
  end
  
  def welcome_page_redirect # If the old ui url is hit directly, redirect to new UI
    action_name == "index" ? (redirect_to :admin_social_streams) : ( current_account.twitter_handles_from_cache.blank? ? 
      (redirect_to :social_welcome_index)  : (redirect_to :social_streams) )
  end

end
