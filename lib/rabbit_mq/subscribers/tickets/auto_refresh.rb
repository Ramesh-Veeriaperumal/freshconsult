module RabbitMq::Subscribers::Tickets::AutoRefresh
  
  include RabbitMq::Constants

  def mq_auto_refresh_ticket_properties(action)
    user_id = User.current ? User.current.id : ""
    to_rmq_json(auto_refresh_keys, action).merge("user_id" => user_id)
  end

  def mq_auto_refresh_subscriber_properties(action)
    { :model_changes => model_changes_hash}
  end

  def mq_auto_refresh_valid(action, model)
    destroy_action?(action) ? false : (valid_model?(model) && auto_refresh_allowed? && model_changes?)
  end

  private

  def auto_refresh_keys
    AUTO_REFRESH_TICKET_KEYS + [{"custom_fields" => (filter_custom_fields.map(&:flexifield_alias) || [])}]
  end

  def model_changes_hash
    changes = { :custom_fields => {}}
    flexifields = Hash[filter_custom_fields.map{|entry| [entry.flexifield_name, entry.flexifield_alias]}]
    @model_changes.each do |key, value|
      unless value[0].blank?
        if flexifields[key.to_s]
          changes[:custom_fields][flexifields[key.to_s]] = value
        else
          changes[key.to_s] = value
        end
      end
    end
    changes
  end

  def valid_model?(model)
    ["ticket"].include?(model)
  end

  def filter_custom_fields
    Account.current.flexifields_with_ticket_fields_from_cache.select {|field| !non_filter_fields.include?(field.flexifield_coltype)}
  end

  def non_filter_fields
    FlexifieldDef::TEXT_COL_TYPES + FlexifieldDef::NUM_COL_TYPES
  end

end