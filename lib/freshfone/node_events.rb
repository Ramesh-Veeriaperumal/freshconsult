module Freshfone::NodeEvents

	include Redis::RedisKeys
	include Redis::IntegrationsRedis

  def notify_socket(channel, message)
    message.merge!({:enqueued_time => Time.now})
    Freshfone::NodeWorker.perform_async(message, channel, freshfone_node_session)
  end

  def unpublish_live_call(params = nil, account = nil)
    # remove_value_from_set(live_calls_key, [called_entity])
    notify_socket(call_channel("completed_call", account), call_completed_message)
  end

  def publish_live_call(params, account = nil, user_id = nil)
    # add_to_set(live_calls_key, [called_entity])
    notify_socket(call_channel("new_call", account), new_call_message(account, user_id))
  end

  def publish_new_active_call(call, account = nil)
    @account = account
    notify_socket(call_channel("new_active_call", account), new_active_call_message(call, account))
  end

  def publish_active_call_end(call, account = nil)
    @account = account
    notify_socket(call_channel("active_call_end", account), active_call_end(call, account))

  end

  def publish_queued_call(call, account = nil)
    @account = account
    notify_socket(call_channel("queued_call", account), queued_call_message(call, account))
  end

  def publish_dequeued_call(call, account = nil, user_id = nil)
    @account = account
    notify_socket(call_channel("dequeued_call", account), dequeued_call_message(call, account))
  end

  def publish_disable_supervisor_call(call_id, supervisor_id, account = nil)
    @account = account
    notify_socket(call_channel("disable_supervisor_call", account), disable_supervisor_call_message(call_id,supervisor_id))
  end

  def publish_enable_supervisor_call(call_id, supervisor_id, account = nil)
    @account = account
    notify_socket(call_channel("enable_supervisor_call", account), enable_supervisor_call_message(call_id, supervisor_id))
  end

  def publish_freshfone_presence(user, deleted=false)
    @user = user
    (!deleted and ff_user.online?) ? publish_online : check_user_offline
  end

  def publish_capability_token(user, token = nil)
    @user = user
    notify_socket(capability_token_channel, token_message(token))
  end

  def publish_success_of_call_transfer(user, success = true)
    @user = user
    notify_socket(call_transfer_success_channel, success_transfer_message(success))
  end

  def check_user_offline
    ff_user.offline? ? publish_offline : check_for_busy
  end

  def check_for_busy
    ff_user.busy? ? publish_busy : publish_acw
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

  def publish_acw
    notify_socket(presence_channel('agent_in_acw_state'), offline_message)
  end
  
  def publish_agent_device(fuser,user)
    @user = user
    notify_socket(presence_channel("toggle_device"), online_message)
  end


  def publish_freshfone_widget_state(account, status)
    @account = account
    notify_socket(credits_channel(status), {})
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
      { :type => "completed_call" }
    end

    def new_call_message(account = nil, user_id = nil)
      account ||= current_account
      { :type => "new_call", 
        :agent => user_id || called_entity }
    end

    def success_transfer_message(success)
      {
        :agent_id => @user.id,
        :success => success
      }
    end

    def call_detail_params(call)
      {
          :call_id => call.id,
          :caller_name => call.customer.present? ?  user_link(call.customer) : call.caller_number,
          :caller_avar => get_user_avatar(call.customer, true),
          :user_location => call.location,
          :agent_user_avatar => get_user_avatar(call.agent),
          :agent_group_name => get_agent_or_group_name(call),
          :helpdesk_number => call.direct_dial_number.present? ? call.direct_dial_number : call.freshfone_number.number,
          :direction => call.incoming? ? "ficon-incoming-call" : "ficon-outgoing-call",
          :call_created_at => call.created_at.to_i
        }
    end

    def queued_call_message(call, account) 
      { :call_details => call_detail_params(call) }
    end

    def get_agent_or_group_name(call)
      if call.agent.present? 
        user_link(call.agent)
      elsif call.group.present?
        call.group.name 
      elsif external_transfer?(call)
        I18n.t('freshfone.call_history.external')
      else
        I18n.t('freshfone.call_history.helpdesk') 
      end
    end

    def get_user_avatar(user, is_customer = false)
      helper = ApplicationController.helpers
      avatar = "<div class='callhistory_helpdesk_avatar vertical-alignment ff-png-icon'></div>"
      if user.present?
        avatar = helper.user_avatar(user, :thumb, "preview_pic") 
      elsif is_customer
       avatar = helper.unknown_user_avatar
      end
      avatar
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
    
    def dequeued_call_message(call, account)
      { :call_details => { :call_id => call.id } }
    end

    def new_active_call_message(call, account)
      { :call_details => call_detail_params(call) }
    end

    def active_call_end(call, account)
      { :call_details => { :call_id => call.id } }
    end

    def disable_supervisor_call_message(call_id, supervisor_id)
      { :call_details => { :call_id => call_id, :user_id => supervisor_id} }
    end

    def enable_supervisor_call_message(call_id, supervisor_id)
      { :call_details => { :call_id => call_id, :user_id => supervisor_id} }
    end

    def user_link(user)
      "<a href=/users/#{user.id} data-contact-id=freshfone_#{user.id} data-pjax='#body-container' data-contact-url=#{hover_card_path(user)} rel='contact-hover'>#{user.name}</a>"
    end
    
    def hover_card_path(user)
      Rails.application.routes.url_helpers.hover_card_contact_path(user)
    end

    def external_transfer?(call)
      return if call.meta.blank?
      call.meta.device_type == Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer]
    end

    def ff_user
      @user.freshfone_user
    end
end