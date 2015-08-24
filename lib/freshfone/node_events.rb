module Freshfone::NodeEvents

	include Redis::RedisKeys
	include Redis::IntegrationsRedis

  def notify_socket(channel, message)
    message.merge!({:enqueued_time => Time.now})
    Freshfone::NodeWorker.perform_async(message, channel, freshfone_node_session)
  end

  def unpublish_live_call(params = nil)
    # remove_value_from_set(live_calls_key, [called_entity])
    notify_socket(call_channel("completed_call"), call_completed_message)
  end

  def publish_live_call(params, account = nil, user_id = nil)
    # add_to_set(live_calls_key, [called_entity])
    notify_socket(call_channel("new_call", account), new_call_message(account, user_id))
  end

  def publish_freshfone_presence(user, deleted=false)
    @user = user
    (!deleted and user.freshfone_user_online?) ? publish_online : check_user_offline(user)
  end

  def publish_capability_token(user, token = nil)
    @user = user
    notify_socket(capability_token_channel, token_message(token))
  end

  def publish_success_of_call_transfer(user, success = true)
    @user = user
    notify_socket(call_transfer_success_channel, success_transfer_message(success))
  end

  def check_user_offline(user)
    (user.freshfone_user_offline?) ? publish_offline : publish_busy
  end

  def publish_online
    notify_socket(presence_channel("agent_available"), online_message)
  end

  def publish_offline
    notify_socket(presence_channel("agent_unavailable"), offline_message)
  end

  def publish_busy
    notify_socket(presence_channel("agent_busy"), offline_message)
  end

  def publish_freshfone_widget_state(account, status)
    @account = account
    notify_socket(credits_channel(status), "")
  end

  def add_active_call_params_to_redis(params, message=nil)
    agent = (current_user.blank?) ? current_account.users.find(params[:agent]) : current_user
    active_call_message = message || { :agent => agent.id }
    set_key(active_calls_key, active_call_message.to_json)
  end

  private
    def called_entity
      params[:direct_dial_number] || (current_user || {})[:id] || params[:agent]
    end
    
    def online_message
      { :members => @user.account.freshfone_users.raw_online_agents.count,
        :user => { :id => @user.id,
                   :name => @user.name, 
                   :avatar => ApplicationController.helpers.user_avatar(@user).to_str,
                   :presence_time => @user.freshfone_user.last_call_at,
                   :on_phone => @user.freshfone_user.available_on_phone
                   }
      }
    end 

    def offline_message
      { :members => @user.account.freshfone_users.raw_online_agents.count,
        :user => { :id => @user.id,
                   :name => @user.name, 
                   :presence_time => @user.freshfone_user.last_call_at,
                   :on_phone => @user.freshfone_user.available_on_phone
                   }
      }
    end

    def token_message(token)
      { :token => token,
        :user => { :id => @user.id }
      }
    end

    def call_completed_message
      { :type => "completed_call", 
        :calls => current_account.freshfone_users.busy_agents.count }
    end

    def new_call_message(account = nil, user_id = nil)
      account ||= current_account
      { :type => "new_call", 
        :agent => user_id || called_entity, 
        :calls => account.freshfone_users.busy_agents.count }
    end

    def success_transfer_message(success)
      {
        :agent_id => @user.id,
        :success => success
      }
    end

    def agent_availability_key
      AGENT_AVAILABILITY % { :account_id => @user.account_id }
    end

    def live_calls_key
      NEW_CALL % { :account_id => current_account.id }
    end

    def active_calls_key
      ACTIVE_CALL % {  :account_id => current_account.id, :call_sid => params[:CallSid] }
    end
    
    def presence_channel(status)
      "#{@user.account_id}/presence/#{status}"
    end

    def call_channel(status, account = nil)
      account ||= current_account
      "#{account.id}/calls/#{status}"
    end

    def capability_token_channel
      "#{@user.account_id}/token/#{@user.id}"
    end
    
    def credits_channel(status)
      "#{@account.id}/credits/#{status}"
    end

    def call_transfer_success_channel 
      "#{@user.account_id}/calltransfer/#{@user.id}"
    end

    def freshfone_node_session
      account = @account || 
                (@user ? @user.account : current_account)
      Digest::SHA512.hexdigest("#{FreshfoneConfig['secret_key']}::#{account.id}")
    end
    
end