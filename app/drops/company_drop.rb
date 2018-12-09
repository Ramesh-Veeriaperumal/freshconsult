class CompanyDrop < BaseDrop	
  
  include DateHelper
  
  self.liquid_attributes += [:name, :description, :note, :domains,
                             :health_score, :account_tier, :industry, :renewal_date]

  def initialize(source)
    super source
  end

  def description
    @source.description.nil? ? '' : escape_liquid_attribute(@source.description).gsub(/\n/, '<br/>')
  end

  def note
    @source.note.nil? ? '' : escape_liquid_attribute(@source.note).gsub(/\n/, '<br/>')
  end

  def id
    @source.id
  end
	
  def before_method(method)
    field_name = "cf_#{method}"
    @field_mappings ||= @source.custom_field_types
    required_field_type = @field_mappings[field_name]
    return super unless required_field_type
    required_field_value = @source.custom_field["cf_#{method}"]
    formatted_field_value(required_field_type, required_field_value)
  end

end