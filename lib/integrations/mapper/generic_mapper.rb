class Integrations::Mapper::GenericMapper
  def template_convert(from_entity, config)
    input_entity = from_entity.respond_to?(:attributes) ? from_entity.attributes : from_entity
    Rails.logger.debug "GenericMapper:: input_entity #{input_entity.inspect}, config_value #{config[:value]}"
    set_data = Liquid::Template.parse(config[:value]).render(input_entity)
  end

  def static_value(from_entity, config)
    config[:value]
  end

  def map_field(from_entity, config)
    set_data = self.template_convert(from_entity, config)
    set_data = config[:mapping_values][set_data]
    set_data = config[:mapping_values]["Default"] if set_data.blank?
    set_data
  end
end
