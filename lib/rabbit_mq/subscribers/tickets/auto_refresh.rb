module RabbitMq::Subscribers::Tickets::AutoRefresh
  
  include RabbitMq::Constants

  def mq_auto_refresh_ticket_properties(action)
    user_id = User.current ? User.current.id : ""
    to_rmq_json(auto_refresh_keys, action).merge("user_id" => user_id)
  end

  def mq_auto_refresh_subscriber_properties(action)
    {}
  end

  def mq_auto_refresh_valid(action)
    destroy_action?(action) ? false : autorefresh_node_allowed? && model_changes?
  end

  private

  def auto_refresh_keys
    AUTO_REFRESH_TICKET_KEYS + [{"custom_fields" => ff_aliases}]
  end
end