module Import::Zen::FlexiField

 include Import::CustomField
 include Import::Zen::Redis
 include Redis::OthersRedis
 
  class FieldOption < Import::FdSax
    element :name
    element :value
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
    ff_def = @current_account.ticket_field_def
    @invalid_fields = []
    custom_props =  FieldProp.parse(field_xml)
    build_redis_hash(custom_props) if custom_props.choices.present?
    flexifield = ff_def.flexifield_def_entries.find_by_import_id(custom_props.import_id)
    return unless flexifield.blank?
    return unless (custom_props.field_type = ZENDESK_FIELD_TYPES[custom_props.field_type])
    field_prop = custom_props.to_hash.merge({:position => 100 , :type =>custom_props.field_type ,:field_type => "custom_#{custom_props.field_type}"})
    if(field_prop[:field_type] == "custom_dropdown")
      field_prop[:picklist_values_attributes] = custom_props.choices.collect{|c| {:value => c.name}}
    else
      field_prop[:choices] = custom_props.choices.collect{|c| [c.name]}
    end
    create_field field_prop, @current_account   
  end

  def build_redis_hash(custom_props)
    current_custom_dropdown_hash = custom_props.choices.inject({}) do |custom_dropdown_hash, choice|
      custom_dropdown_hash.merge("#{custom_props.import_id}_#{choice.value}" => choice.name)
    end
    set_others_redis_hash(zen_dropdown_key, current_custom_dropdown_hash)
  end
       
end