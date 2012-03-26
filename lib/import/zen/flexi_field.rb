module Import::Zen::FlexiField

 include Import::CustomField
 
  class FieldOption < Import::FdSax
    element :name
  end
  
  class FieldProp < Import::FdSax   
    element :type , :as => :field_type
    element :id , :as => :import_id
    element :title , :as => :label
    element "is-required" , :as => :required
    element "is-visible-in-portal" , :as => :visible_in_portal
    element "is-editable-in-portal" , :as => :editable_in_portal
    element "is-required-in-portal" , :as => :required_in_portal
    element :description
    elements "custom-field-option" , :as => :choices ,:class => FieldOption
  end


  def save_record field_xml
    ff_def = @current_account.flexi_field_defs.first
    @invalid_fields = []
    custom_props =  FieldProp.parse(field_xml)
    flexifield = ff_def.flexifield_def_entries.find_by_import_id(custom_props.import_id)
    return unless flexifield.blank?
    return unless (custom_props.field_type = ZENDESK_FIELD_TYPES[custom_props.field_type])
    field_prop = custom_props.to_hash.merge({:position => 100 , :type =>custom_props.field_type ,:field_type => "custom_#{custom_props.field_type}"})
    field_prop[:choices] = custom_props.choices.collect{|c| [c.name]}
    create_field field_prop, @current_account   
  end
       
end