module Freshfone::NodeNotifier

  #All node communications goes through this module.

  def notify_call_hold(current_call)
    channel = "conference/#{@current_account.id}/calls/call_holded"
    message = {
      :call_sid => current_call.call_sid,
      :agent => current_call.agent.id
    }
    publish(message, channel)
  end

  def notify_call_unhold(current_call)
    channel = "conference/#{@current_account.id}/calls/call_unholded"
    message = {
      :call_sid => current_call.call_sid,
      :agent => current_call.agent.id
    }
    publish(message, channel)
  end

  def notify_transfer_success(current_call)
    channel = "conference/#{@current_account.id}/calls/transfer_success"
    message ={
        :call_sid => current_call.call_sid,
        :agent => current_call.user_id
      }
    publish(message, channel)
  end

  def notify_agent_conference_status(current_call, node_event, call_status = nil)
    channel = "conference/#{@current_account.id}/calls/#{node_event}"
    message = {
      call_sid: current_call.call_sid,
      agent: current_call.user_id,
      call_status: call_status
    }
    publish(message, channel)
  end

  def notify_warm_transfer_status(current_call, node_event, call_status = nil)
    channel = "conference/#{@current_account.id}/calls/warm_transfer_event"
    message = {
      call_sid: current_call.agent_sid,
      call_id: current_call.id,
      agent: current_call.user_id,
      call_status: call_status,
      event_type: node_event
    }
    publish(message, channel)
  end

  def notify_transfer_reconnected(current_call)
    channel = "conference/#{@current_account.id}/calls/transfer_reconnected"
    message ={
        :call_sid => current_call.call_sid,
        :agent => current_call.user_id
      }
    publish(message, channel)
  end

  def notify_transfer_unanswered(current_call)
    channel = "conference/#{@current_account.id}/calls/transfer_unanswered"
    message ={
        :call_sid => current_call.call_sid,
        :agent => current_call.user_id
      }
    publish(message, channel)
  end

  def publish(message, channel)
    Rails.logger.debug "Freshfone Node sidekiq: #{@current_account.id} : #{channel}"
    Rails.logger.debug message
    message.merge!({:enqueued_time => Time.now})
    Freshfone::NodeWorker.perform_async(message, channel, freshfone_node_session)
  end

  private
    def freshfone_node_session
      @node_session ||= Digest::SHA512.hexdigest("#{FreshfoneConfig['secret_key']}::#{@current_account.id}")
    end
  
end