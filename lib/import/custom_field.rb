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

  def import_flexifields base_dir
    doc = REXML::Document.new(File.new(File.join(base_dir, "ticket_fields.xml")))
    ff_def = current_account.flexi_field_defs.first
    
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
      
      create_field field_prop
    end
  end
  
  def create_field(field_details)
    ff_def_entry = FlexifieldDefEntry.new ff_meta_data(field_details)
    field_details.delete(:id)
    ticket_field = current_account.ticket_fields.build(field_details)
    ticket_field.name = ff_def_entry.flexifield_alias
    ticket_field.flexifield_def_entry = ff_def_entry
    ticket_field.save!
  end
  
  def ff_meta_data(field_details)
    type = field_details.delete(:type)
    ff_def = current_account.flexi_field_defs.first
    ff_def_entries = ff_def.flexifield_def_entries.all(:conditions => { 
      :flexifield_coltype => FIELD_COLUMN_MAPPING[type][0] })

    used_columns = ff_def_entries.collect { |ff_entry| ff_entry.flexifield_name }
    available_columns = FIELD_COLUMN_MAPPING[type][1] - used_columns
    
    { 
      :flexifield_def_id => ff_def.id, 
      :flexifield_name => available_columns.first,
      :flexifield_coltype => type, 
      :flexifield_alias => field_name(field_details[:label]), 
      :flexifield_order => field_details[:position], #ofc. there'll be gaps.
      :import_id => field_details.delete(:import_id)
    }
  end
  
  def field_name(label)
    "#{label.strip.gsub(/\s/, '_').gsub(/\W/, '').downcase}_#{current_account.id}"
  end
end
