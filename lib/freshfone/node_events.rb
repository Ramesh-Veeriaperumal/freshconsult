module Freshfone::NodeEvents

	include Redis::RedisKeys
	include Redis::IntegrationsRedis
	include ApplicationHelper
	include ActionView::Helpers::TagHelper
	include ActionView::Helpers::AssetTagHelper

  def notify_socket(channel, message)
    begin
      node_uri = "#{FreshfoneConfig['node_url'][Rails.env]}/freshfone/#{channel}"
      options = {
        :body => message, 
        :headers => { "X-Freshfone-Session" => freshfone_node_session },
        :timeout => 15
      }
      HTTParty.post(node_uri, options)  
    rescue Timeout::Error
      Rails.logger.error "Timeout trying to publish freshfone event for #{node_uri}. \n#{options.inspect}"
      NewRelic::Agent.notice_error(e, {:description => "Error publishing data to Freshfone node"})
    rescue Exception => e
      Rails.logger.error "Error publishing data to Freshfone Node. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e, {:description => "Timeout trying to publish freshfone event for #{node_uri}"})
    end
  end

  def unpublish_live_call(params)
    remove_value_from_set(live_calls_key, [called_entity])
    notify_socket(call_channel("completed_call"), call_completed_message)
  end

  def publish_live_call(params)
    add_to_set(live_calls_key, [called_entity])
    notify_socket(call_channel("new_call"), new_call_message)
  end

  def publish_freshfone_presence(user, deleted=false)
    @user = user
    (!deleted and user.freshfone_user_online?) ? publish_online : publish_offline
  end

  def publish_online
    add_to_set(agent_availability_key, @user.id)
    notify_socket(presence_channel("agent_available"), online_message)
  end

  def publish_offline
    remove_value_from_set(agent_availability_key, @user.id)
    notify_socket(presence_channel("agent_unavailable"), offline_message)
  end

  def add_active_call_params_to_redis(params, message=nil)
    agent = (current_user.blank?) ? current_account.users.find(params[:agent]) : current_user
    active_call_message = message || {
                                        :agent => agent.id, 
                                        :requester => params[:From],
                                        :call_sid => params[:CallSid], 
                                        :original_status => agent.freshfone_user_presence
                                      }
    set_key(active_calls_key, active_call_message.to_json)
  end

  private
    def called_entity
      params[:direct_dial_number] || (current_user || {})[:id] || params[:agent]
    end
    
    def online_message
      { :members => integ_set_members(agent_availability_key).count,
        :user => { :id => @user.id,
                   :name => @user.name, 
                   :avatar => user_avatar(@user)}}
    end

    def offline_message
      { :members => integ_set_members(agent_availability_key).count,
        :user => { :id => @user.id }}
    end

    def call_completed_message
      { :type => "completed_call", 
        :calls => integ_set_members(live_calls_key).count }
    end

    def new_call_message
      { :type => "new_call", 
        :agent => called_entity, 
        :calls => integ_set_members(live_calls_key).count }
    end

    def agent_availability_key
      AGENT_AVAILABILITY % { :account_id => @user.account_id }
    end

    def live_calls_key
      NEW_CALL % { :account_id => current_account.id }
    end

    def active_calls_key
      ACTIVE_CALL % { :call_sid => params[:CallSid] }
    end
    
    def presence_channel(status)
      "#{@user.account_id}/presence/#{status}"
    end

    def call_channel(status)
      "#{current_account.id}/calls/#{status}"
    end

    def freshfone_node_session
      account = @user ? @user.account : current_account
      Digest::SHA512.hexdigest("#{FreshfoneConfig['secret_key'][Rails.env]}::#{account.id}")
    end
    
end