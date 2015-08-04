
module RabbitMq::Subscribers::Notes::AutoRefresh
  
  include RabbitMq::Constants

  def mq_auto_refresh_note_properties(action)
    user_id = User.current ? User.current.id : ""
    to_rmq_json(auto_refresh_keys, action).merge("user_id" => user_id)
  end

  def mq_auto_refresh_subscriber_properties(action)
    {}
  end

  def mq_auto_refresh_valid(action, model)
    #destroy_action?(action) ? false : (valid_model?(model) && account.features?(:autorefresh_node))
    false
  end

  private

  def auto_refresh_keys
    AUTO_REFRESH_NOTE_KEYS
  end

  def valid_model?(model)
    ["note"].include?(model)
  end

end