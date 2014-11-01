module RabbitMq::Subscribers::Tickets::ChromeExtension
  
  include RabbitMq::Constants
  MODEL_CHANGE_KEYS = [:responder_id,:group_id,:status]

  def mq_chrome_extension_ticket_properties(action)
    properties = get_properties(self)
    properties["users_notify"] = users_to_be_notified(action,properties)
    properties
  end

  def mq_chrome_extension_subscriber_properties
    {}
  end

  def mq_chrome_extension_valid
    (@model_changes.keys &  MODEL_CHANGE_KEYS).any? 
  end


  private

  def users_to_be_notified(action,properties)
    (action == "create") ? create_notification_users(properties) : update_notification_users(properties)
  end

  def create_notification_users(properties)
    properties["actions"].push(ACTION[:new])
    user_ids = responder_id.nil? ? [] : [responder_id]

    if group_id
      begin
        user_ids.push(*self.account.groups.find(group_id).agent_groups.map(&:user_id))
      rescue Exception => e
        ### When the group_id is invalid (before deleteing email_configs invalid entries),
        ### new ticket notification is sent.
      end
    end

    user_ids.uniq
  end

  def update_notification_users(properties)
    assigned_ticket = responder_id ? true : false;
    user_ids = []
    current_user_id = User.current ? User.current.id : ""
  
    if @model_changes.key?(:responder_id) && responder_id
      user_ids.push(responder_id)
      properties["actions"].push(ACTION[:user_assign])
    end
    # unasigned tickets? should we send a notification 
    if (assigned_ticket && (@model_changes.key?(:group_id) || @model_changes.key?(:status)))
      if group_id then
        begin
          user_ids.push(*self.account.groups.find(group_id).agent_groups.map(&:user_id))
          properties["actions"].push(ACTION[:group_assign])
        rescue Exception => e
          ### When the group_id is invalid (before deleteing email_configs invalid entries)
        end
      end
    end

    if @model_changes.key?(:status)
      properties["actions"].push(ACTION[:status_update])
      user_ids.push(responder_id) unless responder_id.blank?
    end   

    user_ids.uniq
  end
 
end