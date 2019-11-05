# Freshquery Initializer
module Freshquery
  class FqTicketHelper
    include Singleton

    def status_ids
      proc { Account.current.ticket_status_values_from_cache.map(&:status_id) }
    end

    def ticket_types
      TicketsValidationHelper.ticket_type_values
    end

    def priorities
      ApiTicketConstants::PRIORITIES
    end

    def custom_string_mappings
      proc { Account.current.flexifields_with_ticket_fields_from_cache.map { |x| [TicketDecorator.display_name(x.flexifield_alias), x.flexifield_name] if x.ticket_field.field_type == 'custom_text' }.compact.to_h }
    end

    def custom_number_mappings
      proc { Account.current.flexifields_with_ticket_fields_from_cache.map { |x| [TicketDecorator.display_name(x.flexifield_alias), x.flexifield_name] if x.ticket_field.field_type == 'custom_number' }.compact.to_h }
    end

    def custom_checkbox_mappings
      proc { Account.current.flexifields_with_ticket_fields_from_cache.map { |x| [TicketDecorator.display_name(x.flexifield_alias), x.flexifield_name] if x.ticket_field.field_type == 'custom_checkbox' }.compact.to_h }
    end

    def custom_dropdown_mappings
      proc { Account.current.flexifields_with_ticket_fields_from_cache.map { |x| [TicketDecorator.display_name(x.flexifield_alias), x.flexifield_name] if x.ticket_field.field_type == 'custom_dropdown' }.compact.to_h }
    end

    def custom_dropdown_choices
      proc { TicketsValidationHelper.custom_dropdown_field_choices.map { |k, v| [TicketDecorator.display_name(k), v] }.to_h }
    end

    # def custom_date_mappings
    # 	proc{ Account.current.flexifield_def_entries.map{|x| [TicketDecorator.display_name(x.flexifield_alias), x.flexifield_name] if x.ticket_field.field_type == "custom_date" }.compact.to_h }
    # end

    def custom_string_fields
      proc { Account.current.flexifield_def_entries.map { |x| x.flexifield_name if x.ticket_field.field_type == 'custom_text' }.compact }
    end

    def custom_number_fields
      proc { Account.current.flexifield_def_entries.map { |x| x.flexifield_name if x.ticket_field.field_type == 'custom_number' }.compact }
    end

    def custom_dropdown_fields
      proc { Account.current.flexifield_def_entries.map { |x| x.flexifield_name if ['custom_dropdown', 'nested_field'].include?(x.ticket_field.field_type)}.compact }
    end
  end

  class FqTicketAnalyticsHelper < FqTicketHelper
    include Singleton

    def custom_dropdown_mappings
      proc { Account.current.flexifields_with_ticket_fields_from_cache.map { |x| [TicketDecorator.display_name(x.flexifield_alias), x.flexifield_name] if ['custom_dropdown', 'nested_field'].include?(x.ticket_field.field_type) }.compact.to_h }
    end

   def custom_dropdown_choices
     proc { TicketsValidationHelper.custom_dropdown_field_choices.map { |k, v| [TicketDecorator.display_name(k), v] }.to_h.merge(
      Hash.new.tap do |nested_val_hash|
        Account.current.nested_fields_from_cache.each do |nested_value|
          level1_key = TicketDecorator.display_name(nested_value.name)
          level2_key = nested_value.nested_ticket_fields.find{|x| x.level == 2 }.try(:name)
          level3_key = nested_value.nested_ticket_fields.find{|x| x.level == 3 }.try(:name)
          choices = nested_value.formatted_nested_choices
          nested_val_hash[level1_key] = choices.keys
          if level2_key.present?
            level2_array = choices.keys.map { |k| choices[k] }
            level2_values = level2_array.map(&:keys).flatten.uniq
            nested_val_hash[TicketDecorator.display_name(level2_key)] = level2_values
            if level3_key.present?
              level3_values = level2_array.map(&:values).flatten.uniq
              nested_val_hash[TicketDecorator.display_name(level3_key)] = level3_values
            end
          end
        end
      end) }
   end
  end

  class FqContactHelper
    include Singleton

    def all_languages
      I18n.available_locales.map(&:to_s)
    end

    def all_zones
      ActiveSupport::TimeZone.all.map(&:name).freeze
    end

    def custom_string_mappings
      proc { Account.current.contact_form.custom_contact_fields.map { |x| [CustomFieldDecorator.display_name(x.name), x.column_name] if x.field_type == :custom_text }.compact.to_h }
    end

    def custom_number_mappings
      proc { Account.current.contact_form.custom_contact_fields.map { |x| [CustomFieldDecorator.display_name(x.name), x.column_name] if x.field_type == :custom_number }.compact.to_h }
    end

    def custom_checkbox_mappings
      proc { Account.current.contact_form.custom_contact_fields.map { |x| [CustomFieldDecorator.display_name(x.name), x.column_name] if x.field_type == :custom_checkbox }.compact.to_h }
    end

    def custom_dropdown_mappings
      proc { Account.current.contact_form.custom_contact_fields.map { |x| [CustomFieldDecorator.display_name(x.name), x.column_name] if x.field_type == :custom_dropdown }.compact.to_h }
    end

    def custom_dropdown_choices
      proc { Account.current.contact_form.custom_dropdown_field_choices.map { |k, v| [CustomFieldDecorator.display_name(k), v] }.to_h }
    end

    # def custom_date_mappings
    # 	proc { Account.current.contact_form.custom_contact_fields.map{|x| [CustomFieldDecorator.display_name(x.name), x.column_name] if x.field_type == :custom_date }.compact.to_h }
    # end

    def email_regex
      AccountConstants::EMAIL_VALIDATOR
    end
  end

  class FqCompanyHelper
    include Singleton

    def custom_string_mappings
      proc { Account.current.company_form.custom_company_fields.map { |x| [CustomFieldDecorator.display_name(x.name), x.column_name] if x.field_type == :custom_text }.compact.to_h }
    end

    def custom_number_mappings
      proc { Account.current.company_form.custom_company_fields.map { |x| [CustomFieldDecorator.display_name(x.name), x.column_name] if x.field_type == :custom_number }.compact.to_h }
    end

    def custom_checkbox_mappings
      proc { Account.current.company_form.custom_company_fields.map { |x| [CustomFieldDecorator.display_name(x.name), x.column_name] if x.field_type == :custom_checkbox }.compact.to_h }
    end

    def custom_dropdown_mappings
      proc { Account.current.company_form.custom_company_fields.map { |x| [CustomFieldDecorator.display_name(x.name), x.column_name] if x.field_type == :custom_dropdown }.compact.to_h }
    end

    def custom_dropdown_choices
      proc { Account.current.company_form.custom_dropdown_field_choices.map { |k, v| [CustomFieldDecorator.display_name(k), v] }.to_h }
    end

    # def custom_date_mappings
    # 	proc { Account.current.company_form.custom_company_fields.map{|x| [CustomFieldDecorator.display_name(x.name), x.column_name] if x.field_type == :custom_date }.compact.to_h }
    # end
  end

  class Runner
    include Freshquery::Model
    include Singleton

    fq_schema 'ticket', FqTicketHelper.instance, 512 do
      attribute :priority, choices: :priorities
      attribute :status, choices: :status_ids
      attribute :group_id, type: :positive_integer
      attribute :agent_id, transform: :responder_id, type: :positive_integer
      attribute :created_at, :updated_at, :due_by, type: :date
      attribute :fr_due_by, transform: :frDueBy, type: :date
      attribute :type, transform: :ticket_type, choices: :ticket_types
      attribute :tag, transform: :tag_names, type: :string
      
      # Existing approach per_field filter
      custom_string mappings: :custom_string_mappings
      custom_number mappings: :custom_number_mappings
      custom_boolean mappings: :custom_checkbox_mappings
      custom_dropdown mappings: :custom_dropdown_mappings, choices: :custom_dropdown_choices
      
      # New Approach and the query format will be type based filter
      # (custom_number:1 or custom_number:2) AND (custom_string:'AXV1234' or custom_dropdown:'Incident')
      custom_attributes type: 'custom_string', mappings: :custom_string_fields
      custom_attributes type: 'custom_number', mappings: :custom_number_fields
      custom_attributes type: 'custom_dropdown', mappings: :custom_dropdown_fields
    end


    fq_schema 'archiveticket', FqTicketHelper.instance, 512 do
      attribute :priority, choices: :priorities
      attribute :status, choices: :status_ids
      attribute :group_id, type: :positive_integer
      attribute :agent_id, transform: :responder_id, type: :positive_integer
      attribute :display_id, type: :positive_integer
      attribute :created_at, type: :date
      attribute :requester_id, transform: :requester_id, type: :positive_integer
      attribute :type, transform: :ticket_type, choices: :ticket_types
      attribute :tag, transform: :tag_names, type: :string
      attribute :source, type: :positive_integer
      attribute :company_id, type: :positive_integer
      attribute :product_id, type: :positive_integer
    end

    fq_schema 'user', FqContactHelper.instance, 512 do
      attribute :company_id, transform: :company_ids, type: :positive_integer
      attribute :twitter_id, :mobile, :phone, type: :string
      attribute :active, type: :boolean
      attribute :email, transform: :emails, regex: :email_regex
      attribute :tag, transform: :tag_names, type: :string
      attribute :language, choices: :all_languages
      attribute :time_zone, choices: :all_zones
      attribute :created_at, :updated_at, type: :date
      custom_string mappings: :custom_string_mappings
      custom_number mappings: :custom_number_mappings
      custom_boolean mappings: :custom_checkbox_mappings
      custom_dropdown mappings: :custom_dropdown_mappings, choices: :custom_dropdown_choices
      # custom_date mappings: :custom_date_mappings
    end

    fq_schema 'company', FqCompanyHelper.instance, 512 do
      attribute :domain, transform: :domains, type: :string
      attribute :created_at, :updated_at, type: :date
      custom_string mappings: :custom_string_mappings
      custom_number mappings: :custom_number_mappings
      custom_boolean mappings: :custom_checkbox_mappings
      custom_dropdown mappings: :custom_dropdown_mappings, choices: :custom_dropdown_choices
      # custom_date mappings: :custom_date_mappings
    end

    # skipping validation for count cluster alone
    fq_schema 'ticketanalytics', FqTicketAnalyticsHelper.instance, 8192, false do
      attribute :priority, choices: :priorities
      attribute :status, choices: :status_ids
      attribute :group_id, :internal_group_id,  type: :positive_integer
      attribute :agent_id, transform: :responder_id, type: :positive_integer
      attribute :internal_agent_id, :sl_skill_id, type: :positive_integer
      attribute :created_at, :updated_at, :due_by, type: :date_time
      attribute :fr_due_by, transform: :frDueBy, type: :date_time
      attribute :type, transform: :ticket_type, choices: :ticket_types, type: :string
      attribute :tag, transform: :tag_names, type: :string
      attribute :spam, :deleted, :trashed, :status_stop_sla_timer, :status_deleted, type: :boolean
      attribute :product_id, :source, :company_id, :association_type, :watchers, :tag_ids, type: :positive_integer
      attribute :requester_id, transform: :requester_id, type: :positive_integer
      attribute :fsm_appointment_start_time, :fsm_appointment_end_time, type: :date_time
      custom_dropdown mappings: :custom_dropdown_mappings, choices: :custom_dropdown_choices
    end
  end

  class DefaultQueries
    include Singleton
    # Use this class to set and reuse an instance variable for default/frequently used queries
  end
end
