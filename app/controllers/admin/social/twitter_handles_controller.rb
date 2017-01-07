class Admin::Social::TwitterHandlesController < ApplicationController

  include ErrorHandle

  before_filter :build_item, :twitter_wrapper, :only => [:authdone]
  before_filter :load_item, :only => [:destroy]
  
  
  def authdone
    add_to_db
  end

  def add_to_db
    returned_value = sandbox(0) {
      twitter_handle = @wrapper.auth(session[:request_token], session[:request_secret], params[:oauth_verifier])
      handle = scoper.find_by_twitter_user_id(twitter_handle[:twitter_user_id])
      if handle.present?
        handle.attributes = {
          :access_token    => twitter_handle.access_token,
          :access_secret   => twitter_handle.access_secret,
          :last_dm_id      => nil,
          :last_mention_id => nil,
          :state           => Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:active],
          :last_error      => nil
        }
        handle.save
        redirect_to edit_admin_social_twitter_stream_url(handle.default_stream)
      elsif current_account.add_twitter_handle?
        twitter_handle.save
        portal_name = twitter_handle.product ? twitter_handle.product.name : current_account.portal_name
        flash[:notice] = t('twitter.success_signin', :twitter_screen_name => twitter_handle.screen_name, :helpdesk => portal_name)
        redirect_to edit_admin_social_twitter_stream_url(twitter_handle.default_stream)
      else
        redirect_to admin_social_streams_url
      end
    }
    session_cleanup
    if returned_value == 0
      flash[:notice] = t('twitter.not_authorized')
      redirect_to admin_social_streams_url
    end
  end

  def destroy
    flash[:notice] = t('twitter.deleted', :twitter_screen_name => @twitter_handle.screen_name)
    @twitter_handle.destroy
    redirect_to admin_social_streams_url
  end


  private
  def twitter_wrapper
    @wrapper = TwitterWrapper.new(@item, { :product => @current_product,
                                           :current_account => current_account,
                                           :callback_url => url_for(:action => 'authdone')})
  end

  def scoper
    current_account.twitter_handles
  end

  def build_item
    @item = scoper.build
  end

  def load_item
    @twitter_handle = current_account.twitter_handles.find(params[:id])
  end

  def session_cleanup
    session[:request_token]  = nil
    session[:request_secret] = nil
  end

end
