class MigrateFormCustomizers < ActiveRecord::Migration
  DEFAULT_FIELDS_MAPPING = {
    "Requester" => "requester",
    "Subject" => "subject",
    "Source" => "source",
    "Type" => "ticket_type",
    "Status" => "status",
    "Priority" => "priority",
    "Group" => "group",
    "Assigned to" => "agent",
    "Description" => "description"
  }
  
  ALL_TRUE = { :required => true, :visible_in_portal => true, :editable_in_portal => true, 
    :required_in_portal => true }
  
  FORCIBLE_DEFAULTS = { 
    "requester" => ALL_TRUE, "subject" => ALL_TRUE, "description" => ALL_TRUE
  }
  
  def self.up
    Account.all.each do |account|
      f_list = ActiveSupport::JSON.decode(account.form_customizer.json_data)
      f_list.each do |f|
        f.symbolize_keys!
        f[:agent].symbolize_keys!
        f[:customer].symbolize_keys!
      
        t_field = account.ticket_fields.build
        t_field.label = f[:display_name]
        t_field.description = f[:description]
        t_field.required = f[:agent][:required]
        t_field.required_for_closure = f[:agent][:closure] || false
        t_field.visible_in_portal = f[:customer][:visible]
        t_field.editable_in_portal = f[:customer][:editable]
        t_field.required_in_portal = f[:customer][:required]
      
        handle_default_vs_custom(t_field, f)
        t_field.save!
      end
    end
  end
  
  def self.handle_default_vs_custom(t_field, attributes)
    if DEFAULT_FIELDS_MAPPING.key? attributes[:label]
      t_field.name = DEFAULT_FIELDS_MAPPING[attributes[:label]]
      t_field.field_type = "default_#{t_field.name}"
      if FORCIBLE_DEFAULTS.key? t_field.name
        t_field.attributes = FORCIBLE_DEFAULTS[t_field.name]
      end
    else
      t_field.name = attributes[:label]
      t_field.flexifield_def_entry_id = attributes[:columnId]
      t_field.field_type = "custom_#{attributes[:type]}"
      
      populate_pick_lists(t_field, attributes) if "dropdown".eql?(attributes[:type])
    end
  end
  
  def self.populate_pick_lists(t_field, attributes)
    return if(f_entry = FlexifieldDefEntry.find(t_field.flexifield_def_entry_id)).nil?
    
    attributes[:choices].each do |c| 
      f_entry.flexifield_picklist_vals << FlexifieldPicklistVal.new(:value => c["value"])
    end
  end

  def self.down
  end
end
