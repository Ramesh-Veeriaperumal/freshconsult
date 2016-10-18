# encoding: utf-8
module Import::CustomField

  include Helpdesk::Ticketfields::ControllerMethods
  
  ZENDESK_FIELD_TYPES = {
    'FieldCheckbox' => 'checkbox',
    'FieldText' => 'text',
    'FieldTagger' => 'dropdown',
    'FieldInteger' => 'number',
    'FieldTextarea' => 'paragraph',
    'FieldDecimal' => 'decimal'
  }

  def import_flexifields (base_dir, account = current_account)
    doc = REXML::Document.new(File.new(File.join(base_dir, "ticket_fields.xml")))
    ff_def = account.ticket_field_def
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

      if(field_prop[:field_type] == "custom_dropdown")
        field_prop[:picklist_values_attributes] = record.elements.collect("custom-field-options/custom-field-option") do |op|
          {:value => op.elements["name"].text}
        end
      else
        field_prop[:choices] = record.elements.collect("custom-field-options/custom-field-option") do |op|
          [op.elements["name"].text]
        end
      end

      create_field field_prop, account
    end
  end
end
