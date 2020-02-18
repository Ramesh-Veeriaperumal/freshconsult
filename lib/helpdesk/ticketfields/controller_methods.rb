module Helpdesk::Ticketfields::ControllerMethods
  include Helpdesk::Ticketfields::Constants

  def create_field(field_details, account = current_account)
    ff_def_entry = FlexifieldDefEntry.new ff_meta_data(field_details, account)
    field_details.delete(:id)
    nested_fields = field_details.delete(:levels)
    field_details.merge!(flexifield_def_entry_details(ff_def_entry))
    ticket_field = scoper(account).build(field_details)
    ticket_field.name = ff_def_entry.flexifield_alias
    ticket_field.flexifield_def_entry = ff_def_entry

    unless ticket_field.save
      @invalid_fields.push(ticket_field)
      remove_from_used_columns(ticket_field)
      return
    end
    ticket_field.insert_at(field_details[:position]) unless field_details[:position].blank?

    if ticket_field.field_type == "nested_field"
      (nested_fields || []).each do |nested_field|
        nested_field.symbolize_keys!
        nested_field.delete(:action)
        type = nested_field[:type]
        nested_ff_def_entry = FlexifieldDefEntry.new ff_meta_data(nested_field, account)
        is_saved = create_nested_field(nested_ff_def_entry, ticket_field, nested_field.merge(type: type), account)
        if !is_saved || !construct_child_levels(nested_ff_def_entry, ticket_field, nested_field)
          remove_from_used_columns(ticket_field)
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

  def available_columns(type)
    if ticket_field_limit_increase_enabled?
      (TICKET_FIELD_DATA_COLUMN_MAPPING[type.to_sym][1] - used_columns(type))
    else
      (FIELD_COLUMN_MAPPING[type.to_sym][1] - used_columns(type))
    end
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

    def ff_meta_data(field_details, account = current_account, options = {})
      @signup_flow = options[:signup_flow].presence || false
      type = field_details.delete(:type)
      column_name = available_columns(type).first
      add_to_used_columns(type, column_name)
      label = options[:alias_present] ? field_details[:flexifield_alias] : field_details[:label]
      is_encrypted = (type.to_sym == Helpdesk::TicketField::CUSTOM_FIELD_PROPS[:encrypted_text][:dom_type] || type.to_sym == Helpdesk::TicketField::CUSTOM_FIELD_PROPS[:secure_text][:dom_type])
      {
        flexifield_def_id:  account.ticket_field_def.id,
        flexifield_name:    column_name,
        flexifield_coltype: type,
        flexifield_alias:   field_name(label, account, is_encrypted),
        flexifield_order:   field_details[:position], # ofc. there'll be gaps.
        import_id:          field_details.delete(:import_id)
      }
    end

    def field_name(label, account = current_account, encrypted = false)
      # invalid_start_char = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '_', ' ']
      label = label.gsub(/[^ _0-9a-zA-Z]+/, '')
      label = "rand#{rand(999_999)}" if label.blank?
      prefix = encrypted ? ENCRYPTED_FIELD_LABEL_PREFIX : CUSTOM_FIELD_LABEL_PREFIX
      label = "#{prefix}#{label}"
      "#{label.strip.gsub(/\s/, '_').gsub(/\W/, '').downcase}_#{account.id}".squeeze('_')
    end

    def construct_child_levels(nested_ff_def_entry, ticket_field, nested_field_details)
      nested_field_details.merge!(flexifield_def_entry_details(nested_ff_def_entry))
      child_level = ticket_field.child_levels.build(nested_field_details)
      child_level.name = nested_ff_def_entry.flexifield_alias
      child_level.flexifield_def_entry = nested_ff_def_entry
      child_level.save
    end

    def used_columns(type)
      @used_columns ||= {}
      @used_columns[type] ||= begin
        master_or_slave = @signup_flow ? :run_on_master : :run_on_slave
        Sharding.safe_send(master_or_slave) do
          Account.current.ticket_field_def.flexifield_def_entries.select(:flexifield_name).where(flexifield_coltype: FIELD_COLUMN_MAPPING[type.to_sym][0]).map(&:flexifield_name)
        end
      end
    end

    def add_to_used_columns(type, column_name)
      @used_columns[type] << column_name
    end

    def remove_from_used_columns(ticket_field)
      @used_columns[ticket_field.flexifield_coltype].delete(ticket_field.column_name)
      if ticket_field.field_type == 'nested_field'
        ticket_field.child_levels.each do |child_field|
          @used_columns[child_field.flexifield_coltype].delete(child_field.column_name)
        end
      end
    end

    def ticket_field_limit_increase_enabled?
      @ticket_field_limit_increase_enabled ||= Account.current.ticket_field_limit_increase_enabled?
    end
end
