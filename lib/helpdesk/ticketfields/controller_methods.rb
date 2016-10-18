module Helpdesk::Ticketfields::ControllerMethods

  CHARACTER_FIELDS = (1..80).collect { |n| "ffs_#{"%02d" % n}" }
  NUMBER_FIELDS = (1..20).collect { |n| "ff_int#{"%02d" % n}" }
  DATE_FIELDS = (1..10).collect { |n| "ff_date#{"%02d" % n}" }
  CHECKBOX_FIELDS = (1..10).collect { |n| "ff_boolean#{"%02d" % n}" }
  TEXT_FIELDS = (1..10).collect { |n| "ff_text#{"%02d" % n}" }
  DECIMAL_FIELDS = (1..10).collect { |n| "ff_decimal#{"%02d" % n}" }

  # Whenever you add new fields here, ensure that you add it in search indexing.
  FIELD_COLUMN_MAPPING = {
    "text"         => [["text" , "dropdown"], CHARACTER_FIELDS],
    "nested_field" => [["text" , "dropdown"], CHARACTER_FIELDS],
    "dropdown"     => [["text" , "dropdown"], CHARACTER_FIELDS],
    "number"       => ["number", NUMBER_FIELDS],
    "checkbox"     => ["checkbox", CHECKBOX_FIELDS],
    "date"         => ["date", DATE_FIELDS],
    "paragraph"    => ["paragraph", TEXT_FIELDS],
    "decimal"      => ["decimal", DECIMAL_FIELDS]
  }


	def create_field(field_details , account=current_account)
    ff_def_entry = FlexifieldDefEntry.new ff_meta_data(field_details,account)
    field_details.delete(:id)
    nested_fields = field_details.delete(:levels)
    field_details.merge!(flexifield_def_entry_details(ff_def_entry))
    ticket_field = scoper(account).build(field_details)
    ticket_field.name = ff_def_entry.flexifield_alias
    ticket_field.flexifield_def_entry = ff_def_entry

    @invalid_fields.push(ticket_field) and return unless ticket_field.save
    ticket_field.insert_at(field_details[:position]) unless field_details[:position].blank?

    if ticket_field.field_type == "nested_field"
      (nested_fields || []).each do |nested_field|
        nested_field.symbolize_keys!
        nested_field.delete(:action)
        type = nested_field[:type]
        nested_ff_def_entry = FlexifieldDefEntry.new ff_meta_data(nested_field, account)
        is_saved = create_nested_field(nested_ff_def_entry, ticket_field, nested_field.merge(type: type), account)
        if is_saved
          construct_child_levels(nested_ff_def_entry, ticket_field, nested_field) 
        else
          ticket_field.destroy
          @tkt_field_id_alias_hash = nil
          current_account.reload
          return
        end
      end
    end
  end

  def create_nested_field(nested_ff_def_entry, ticket_field, nested_field, account=current_account)
    incorrect_data = (nested_field[:label].blank? || nested_field[:type].blank? || nested_field[:level].blank?)

    @invalid_fields.push(ticket_field) and ticket_field.errors.add(:base,"Incorrect values for level 2 and level 3 for dependant field") and return false if incorrect_data

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

  private

	  def scoper(account = current_account)
	    account.ticket_fields
	  end

	  def flexifield_def_entry_details(def_entry)
	    {
	      ticket_form_id: def_entry.flexifield_def_id,
	      column_name: def_entry.flexifield_name,
	      flexifield_coltype: def_entry.flexifield_coltype
	    }
	  end

	  def ff_meta_data(field_details, account=current_account)
	    type = field_details.delete(:type)
	    ff_def = account.ticket_field_def
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

	  def field_name(label,account=current_account)
	    invalid_start_char = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "_", " "]
	    label = label.gsub(/[^ _0-9a-zA-Z]+/,"")
	    label = "cf_" + label if invalid_start_char.index(label[0])
	    "#{label.strip.gsub(/\s/, '_').gsub(/\W/, '').downcase}_#{account.id}".squeeze("_")
	  end

	  def construct_child_levels(nested_ff_def_entry, ticket_field, nested_field_details)
	    nested_field_details.merge!(flexifield_def_entry_details(nested_ff_def_entry))
	    child_level = ticket_field.child_levels.build(nested_field_details)
	    child_level.name = nested_ff_def_entry.flexifield_alias
	    child_level.flexifield_def_entry = nested_ff_def_entry
	    unless child_level.save
	      NewRelic::Agent.notice_error("Error in saving the child levels of the nested field", :params => {
	          account_id: Account.current.id, ticket_field_id: ticket_field.id
	        })
	    end
    end

end