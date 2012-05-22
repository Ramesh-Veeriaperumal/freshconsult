module Import::CustomField
  
  ZENDESK_FIELD_TYPES = {
    'FieldCheckbox' => 'checkbox',
    'FieldText' => 'text',
    'FieldTagger' => 'dropdown',
    'FieldInteger' => 'number',
    'FieldTextarea' => 'paragraph'
  }
  
  FIELD_COLUMN_MAPPING = {
    "text"      => [["text" , "dropdown"], Helpdesk::FormCustomizer::CHARACTER_FIELDS],
    "dropdown"  => [["text" , "dropdown"], Helpdesk::FormCustomizer::CHARACTER_FIELDS],
    "number"    => ["number", Helpdesk::FormCustomizer::NUMBER_FIELDS],
    "checkbox"  => ["checkbox", Helpdesk::FormCustomizer::CHECKBOX_FIELDS],
    "date"      => ["date", Helpdesk::FormCustomizer::DATE_FIELDS],
    "paragraph" => ["paragraph", Helpdesk::FormCustomizer::TEXT_FIELDS]
  }

  def import_flexifields (base_dir, account = current_account)
    doc = REXML::Document.new(File.new(File.join(base_dir, "ticket_fields.xml")))
    ff_def = account.flexi_field_defs.first
    @invalid_fields = []
    
    REXML::XPath.each(doc,'//record') do |record|
      field_type = record.elements["type"].text
      import_id = record.elements["id"].text
      flexifield = ff_def.flexifield_def_entries.find_by_import_id import_id
      
      next unless flexifield.blank?
      next unless (field_type = ZENDESK_FIELD_TYPES[field_type])
      
      field_prop = {
        :type => field_type,
        :field_type => "custom_#{field_type}",
        :label => record.elements["title"].text,
        :required => record.elements["is-required"].text,
        :visible_in_portal => record.elements["is-visible-in-portal"].text,
        :editable_in_portal => record.elements["is-editable-in-portal"].text,
        :required_in_portal => record.elements["is-required-in-portal"].text,
        :position => 100, #Heck #$%^^
        :import_id => import_id,
        :description => record.elements["description"].text
      }
      
      field_prop[:choices] = record.elements.collect("custom-field-options/custom-field-option") do |op|
        [op.elements["name"].text]
      end
      
      create_field field_prop, account
    end
  end
  
  def create_field(field_details , account=current_account)
    ff_def_entry = FlexifieldDefEntry.new ff_meta_data(field_details,account)
    field_details.delete(:id)
    nested_fields = field_details.delete(:levels)
    ticket_field = account.ticket_fields.build(field_details)
    ticket_field.name = ff_def_entry.flexifield_alias
    ticket_field.flexifield_def_entry = ff_def_entry
    
    @invalid_fields.push(ticket_field) and return unless ticket_field.save
    ticket_field.insert_at(field_details[:position]) unless field_details[:position].blank?

    if ticket_field.field_type == "nested_field"
      (nested_fields || []).each do |nested_field|
        nested_field.symbolize_keys!
        nested_field.delete(:action)
        is_saved = create_nested_field(ticket_field, nested_field, account)
        ticket_field.destroy and return unless is_saved
      end
    end

  end
  
  def ff_meta_data(field_details, account=current_account)
    type = field_details.delete(:type)
    ff_def = account.flexi_field_defs.first
    ff_def_entries = ff_def.flexifield_def_entries.all(:conditions => { 
      :flexifield_coltype => FIELD_COLUMN_MAPPING[type][0] })

    used_columns = ff_def_entries.collect { |ff_entry| ff_entry.flexifield_name }
    available_columns = FIELD_COLUMN_MAPPING[type][1] - used_columns
    
    { 
      :flexifield_def_id => ff_def.id, 
      :flexifield_name => available_columns.first,
      :flexifield_coltype => type, 
      :flexifield_alias => field_name(field_details[:label], account), 
      :flexifield_order => field_details[:position], #ofc. there'll be gaps.
      :import_id => field_details.delete(:import_id)
    }
  end
  
    def create_nested_field(ticket_field, nested_field, account=current_account)        
        nested_ff_def_entry = FlexifieldDefEntry.new ff_meta_data(nested_field,account)
        nested_field.delete(:id)
        nested_field.delete(:position)
        nested_ticket_field = ticket_field.nested_ticket_fields.build(nested_field)
        nested_ticket_field.name = nested_ff_def_entry.flexifield_alias
        nested_ticket_field.account = account
        nested_ticket_field.flexifield_def_entry = nested_ff_def_entry
        is_saved = nested_ticket_field.save
        @invalid_fields.push(nested_ticket_field) unless is_saved
        is_saved
    end

  def field_name(label,account=current_account)
    "#{label.strip.gsub(/\s/, '_').gsub(/\W/, '').downcase}_#{account.id}"
  end
end
