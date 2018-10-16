module Sync::Transformer::SlaPolicy
  include Sync::Transformer::Util
  ESCALATIONS_KEYS = [:reminder_response, :reminder_resolution, :response, :resolution].freeze

  CONDITIONS_KEY_NAME_MAPPING = {
    'group_id' => 'Group',
    'product_id' => 'Product'
  }.freeze

  def transform_helpdesk_sla_policy_escalations(data, mapping_table = {})
    data = data.symbolize_keys
    ESCALATIONS_KEYS.each do |iterator|
      next if data[iterator].blank?
      data[iterator].each do |k, v|
        v['agents_id'] = apply_id_mapping(v['agents_id'], get_mapping_data('User', mapping_table))
        data[iterator][k] = v
      end
    end
    data
  end

  def transform_helpdesk_sla_policy_conditions(data, mapping_table = {})
    CONDITIONS_KEY_NAME_MAPPING.each do |key, model|
      if data[key].present?
        data[key] = apply_id_mapping(data[key], get_mapping_data(model, mapping_table))
      end
    end
    data
  end
end
