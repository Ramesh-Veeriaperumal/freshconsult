module RabbitMq::Subscribers::Tickets::MarketplaceApp

  include RabbitMq::Constants
  include Redis::MarketplaceAppRedis

  def mq_marketplace_app_valid(action, model)
    create_action?(action) && Account.current.skip_dispatcher?
  end

  def mq_marketplace_app_ticket_properties(action)
    to_rmq_json(marketplace_app_keys, action)
  end

  def mq_marketplace_app_subscriber_properties(action)
    { "eventName" => event_name("ticket", action) }
  end

  def mq_custom_marketplace_app_ticket_method(message)
    set_ticket_details message
    set_ticket_params message
  end

  private

    def marketplace_app_keys
      MARKETPLACE_APP_TICKET_KEYS + [{"custom_fields" => (filter_custom_fields.map(&:flexifield_alias) || [])}]
    end

    def set_ticket_details message
      key = detail_key(message["account_id"])
      set_marketplace_app_redis_key(key, default_score, ticket_key(message))
    end

    def default_score
      Time.now.utc.to_i
    end

    def ticket_key message
      "#{self.display_id}:#{message["uuid"]}"
    end

    def set_ticket_params message
      hash  = automation_params_key(message["account_id"], self.display_id)
      value = dispatcher_params
      set_automation_params_redis_key(hash, message["uuid"], value)
    end

    def dispatcher_params
      {
        :user_id => User.current.try(:id)
      }.to_json
    end

    def observer_params
      {}.to_json
    end

    def event_name(model, action)
      "on#{model.camelize}#{action.camelize}"
    end

    def pod_info
      ShardMapping.lookup_with_account_id(Account.current.id).try(:pod_info)
    end

    def filter_custom_fields
      Account.current.flexifields_with_ticket_fields_from_cache.select {|field| !text_and_number_ff_fields.include?(field.flexifield_coltype)}
    end	
end