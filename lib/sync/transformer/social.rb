module Sync::Transformer::Social
  include Sync::Transformer::Util
  DATA_DEFAULT_VALUES = {
    gnip: 0,
    gnip_rule_state: nil,
    rule_tag: nil
  }.freeze

  ACTION_DATA_NAME_MAPPINGS = {
    group_id: 'Group',
    product_id: 'Product'
  }.freeze

  def transform_social_stream_data(data, mapping_table = {})
    data.each do |key, value|
      if DATA_DEFAULT_VALUES.key?(key)
        data[key] = DATA_DEFAULT_VALUES[key]
      end
    end
    data
  end

  def transform_social_ticket_rule_action_data(data, mapping_table = {})
    data.each do |key, value|
      if ACTION_DATA_NAME_MAPPINGS.key?(key)
        data[key] = apply_id_mapping(data[key], get_mapping_data(ACTION_DATA_NAME_MAPPINGS[key], mapping_table))
      end
    end
    data
  end

  def transform_social_twitter_handle_state(*)
    Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:activation_required]
  end
end
