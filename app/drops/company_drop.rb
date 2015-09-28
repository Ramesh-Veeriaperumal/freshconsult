class CompanyDrop < BaseDrop	
  
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

	
  def before_method(method)
    custom_fields = @source.custom_field
    field_types =  @source.custom_field_types
    if(custom_fields["cf_#{method}"] || field_types["cf_#{method}"])
      unless custom_fields["cf_#{method}"].blank?
        return custom_fields["cf_#{method}"].gsub(/\n/, '<br/>') if field_types["cf_#{method}"] == :custom_paragraph
      end
      custom_fields["cf_#{method}"] 
    else
      super
    end
  end
  
end
