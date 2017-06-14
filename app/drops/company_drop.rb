class CompanyDrop < BaseDrop	
  
  include DateHelper
  
  self.liquid_attributes += [:name, :description, :note, :domains] 

  def initialize(source)
    super source
  end

  def description
    @source.description.nil? ? '' : @source.description.gsub(/\n/, '<br/>')
  end

  def note
    @source.note.nil? ? '' : @source.note.gsub(/\n/, '<br/>')
  end

  def id
    @source.id
  end
	
  def before_method(method)
    required_field_value = @source.custom_field["cf_#{method}"]
    required_field_type = @source.custom_field_types["cf_#{method}"]
    return super unless required_field_type
    formatted_field_value(required_field_type, required_field_value)
  end

end