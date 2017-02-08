module RabbitMq::Subscribers::Tickets::AutoRefresh
  
  include RabbitMq::Constants

  def mq_auto_refresh_ticket_properties(action)
    user_id = User.current ? User.current.id : ""
    to_rmq_json(auto_refresh_keys, action).merge("user_id" => user_id)
  end

  def mq_auto_refresh_subscriber_properties(action)
    { 
      :model_changes => ticket_properties_changes_hash,
      :ticket_channel => AgentCollision.ticket_view_channel(Account.current, display_id)
    }  
  end

  def mq_auto_refresh_valid(action, model)
    destroy_action?(action) ? false : (auto_refresh_valid_model?(model) && auto_refresh_allowed? && model_changes?)
  end

  private

  def auto_refresh_keys
    AUTO_REFRESH_TICKET_KEYS + [{"custom_fields" => (filter_custom_fields.map(&:flexifield_alias) || [])}]
  end

  def ticket_properties_changes_hash
    changes = { :custom_fields => {}}
    flexifields = Hash[filter_custom_fields.map{|entry| [entry.flexifield_name, entry.flexifield_alias]}]
    schemaless_fields = Helpdesk::SchemaLessTicket::COLUMN_TO_ATTRIBUTE_MAPPING
    @model_changes.each do |key, value|
      if value[0].blank?
        #Not need for list, but for details page
        changes["changed_from_nil"] = true
      end 
      if flexifields[key.to_s]
        changes[:custom_fields][flexifields[key.to_s]] = value
      elsif text_and_number_ff_fields.include?(key.to_s)
        changes[:custom_fields]["text_fields"] ||= []
        changes[:custom_fields]["text_fields"] << key.to_s
      elsif schemaless_fields[key]
        changes[ schemaless_fields[key] ] = value
      else
        changes[key.to_s] = value
      end 
    end
    changes
  end

  def auto_refresh_valid_model?(model)
    ["ticket"].include?(model)
  end

  def filter_custom_fields
    Account.current.flexifields_with_ticket_fields_from_cache.select {|field| !text_and_number_ff_fields.include?(field.flexifield_coltype)}
  end

end