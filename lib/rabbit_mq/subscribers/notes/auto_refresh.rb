module RabbitMq::Subscribers::Notes::AutoRefresh
  
  include RabbitMq::Constants

  def mq_auto_refresh_note_properties(action)
    user_id = User.current ? User.current.id : ""
    to_rmq_json(auto_refresh_keys, action).merge("user_id" => user_id)
  end

  def mq_auto_refresh_subscriber_properties(action)
    { 
      :ticket_channel => AgentCollision.ticket_view_channel(Account.current, notable.display_id),
      :agent => User.current ? User.current.agent? : ""
    }  
  end

  def mq_auto_refresh_valid(action, model)
    create_action?(action) ? (valid_model?(model) && Account.current.features?(:collision)) : false
  end

  private

  def auto_refresh_keys
    AUTO_REFRESH_NOTE_KEYS
  end

  def valid_model?(model)
    ["note"].include?(model) && notable_type == "Helpdesk::Ticket"
  end

end