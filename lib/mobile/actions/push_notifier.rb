module Mobile::Actions::Push_Notifier

	include Redis::RedisKeys
	include Mobile::Constants
	include Redis::MobileRedis

	def remove_user_mobile_registrations
        message = {
            :account_id => self.account.id,
            :user_id => self.id,
            :delete_axn => :user
        }.to_json
        puts "DEBUG :: add_to_mobile_reg_queue : message : #{message}"

        publish_to_channel MOBILE_NOTIFICATION_REGISTRATION_CHANNEL, message
	end
	
    def remove_logged_out_user_mobile_registrations
        message = {
            :account_id => current_account.id,
            :user_id => current_user.id,
			:delete_axn => :user
        }.to_json
        puts "DEBUG :: add_to_mobile_reg_queue : message : #{message}"

        publish_to_channel MOBILE_NOTIFICATION_REGISTRATION_CHANNEL, message
    end
	
  def send_mobile_notification(action=:new, message)
    notification_types = Hash.new()

	current_user_id = User.current ? User.current.id : ""
  current_user_name = User.current ? User.current.name : ""

    if action == :new then
      
      if @model_changes.key?(:responder_id) && responder_id != current_user_id then
        notification_types = {NOTIFCATION_TYPES[:TICKET_ASSIGNED] => [responder_id]}
      else
        notification_types = {NOTIFCATION_TYPES[:NEW_TICKET] => []}  
      end
		
    elsif action == :response then
        user_ids = notable.subscriptions.map(&:user_id)
		user_ids.delete(current_user_id)

        user_ids.push(notable.responder_id) unless notable.responder_id.blank? || notable.responder_id == current_user_id || user_ids.include?(notable.responder_id)

		notification_types = {NOTIFCATION_TYPES[:NEW_RESPONSE] => user_ids} unless user_ids.empty?

    else
		process_status_update_notification message, notification_types, current_user_id
    end

    puts "DEBUG :: send_mobile_notification hash : #{notification_types}"
	return if notification_types.empty?
	message.merge!(:notification_types => notification_types, :user => current_user_name)
	message.store(:account_id,self.account.id)
	
    puts "DEBUG :: send_mobile_notification hash : #{message}"
	channel_id = self.account.id%MOBILE_NOTIFICATION_CHANNEL_COUNT

	publish_to_mobile_channel message.to_json, channel_id
  end


  private

  def process_status_update_notification message, notification_types, current_user_id
    unassigned_ticket = true
    if @model_changes.key?(:responder_id) && responder_id && responder_id != current_user_id then
      unassigned_ticket = false
      notification_types.merge! NOTIFCATION_TYPES[:TICKET_ASSIGNED] => [responder_id]
    end
    if unassigned_ticket && @model_changes.key?(:group_id) && group_id then
      user_ids = self.account.groups.find(group_id).agent_groups.map(&:user_id)
      user_ids.delete(current_user_id)
      notification_types.merge! NOTIFCATION_TYPES[:GROUP_ASSIGNED] => user_ids unless user_ids.empty?
    end
    if @model_changes.key?(:status) then
      user_ids = subscriptions.map(&:user_id)
      user_ids.delete(current_user_id)
      user_ids.push(responder_id) unless responder_id.blank? || responder_id == current_user_id || user_ids.include?(responder_id)
      notification_types.merge! NOTIFCATION_TYPES[:STATUS_UPDATE] => user_ids unless user_ids.empty?
    end    
  end

  def publish_to_mobile_channel message, channel_id
	  channel = MOBILE_NOTIFICATION_MESSAGE_CHANNEL % {:channel_id => channel_id}
	  puts "DEBUG :: pushing to channel : #{channel}"
      newrelic_begin_rescue do
          $redis_mobile.publish(channel, message)
      end
  end

  
end
