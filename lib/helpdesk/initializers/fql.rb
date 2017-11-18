module Fql
  class FqTicketHelper
    include Freshquery::ValidationHelper

    def status_ids
      Account.current.ticket_status_values_from_cache.map(&:status_id)
    end

    def ticket_types
      TicketsValidationHelper.ticket_type_values
    end

    def priorities
      ApiTicketConstants::PRIORITIES
    end

    def custom_string_mappings
      proc { Account.current.flexifield_def_entries.map { |x| [TicketDecorator.display_name(x.flexifield_alias), x.flexifield_name] if x.ticket_field.field_type == 'custom_text' }.compact.to_h }
    end

    def custom_number_mappings
      proc { Account.current.flexifield_def_entries.map { |x| [TicketDecorator.display_name(x.flexifield_alias), x.flexifield_name] if x.ticket_field.field_type == 'custom_number' }.compact.to_h }
    end

    def custom_checkbox_mappings
      proc { Account.current.flexifield_def_entries.map { |x| [TicketDecorator.display_name(x.flexifield_alias), x.flexifield_name] if x.ticket_field.field_type == 'custom_checkbox' }.compact.to_h }
    end

    def custom_dropdown_mappings
      proc { Account.current.flexifield_def_entries.map { |x| [TicketDecorator.display_name(x.flexifield_alias), x.flexifield_name] if x.ticket_field.field_type == 'custom_dropdown' }.compact.to_h }
    end

    def custom_dropdown_choices
      proc { TicketsValidationHelper.custom_dropdown_field_choices.map { |k, v| [TicketDecorator.display_name(k), v] }.to_h }
    end

    # def custom_date_mappings
    # 	proc{ Account.current.flexifield_def_entries.map{|x| [TicketDecorator.display_name(x.flexifield_alias), x.flexifield_name] if x.ticket_field.field_type == "custom_date" }.compact.to_h }
    # end
  end

  class FqContactHelper
    include Freshquery::ValidationHelper

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
    include Freshquery::ValidationHelper

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

    mappings 'ticket', FqTicketHelper.instance do
      attribute :priority, choices: :priorities
      attribute :status, choices: :status_ids
      attribute :group_id, type: :positive_integer
      attribute :agent_id, transform: :responder_id, type: :positive_integer
      attribute :created_at, :updated_at, :due_by, type: :date
      attribute :fr_due_by, transform: :frDueBy, type: :date
      attribute :type, transform: :ticket_type, choices: :ticket_types
      attribute :tag, transform: :tag_names, type: :string
      custom_string mappings: :custom_string_mappings
      custom_number mappings: :custom_number_mappings
      custom_boolean mappings: :custom_checkbox_mappings
      custom_dropdown mappings: :custom_dropdown_mappings, choices: :custom_dropdown_choices
      # custom_date mappings: :custom_date_mappings
    end

    mappings 'user', FqContactHelper.instance do
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

    mappings 'company', FqCompanyHelper.instance do
      attribute :domain, transform: :domains, type: :string
      attribute :created_at, :updated_at, type: :date
      custom_string mappings: :custom_string_mappings
      custom_number mappings: :custom_number_mappings
      custom_boolean mappings: :custom_checkbox_mappings
      custom_dropdown mappings: :custom_dropdown_mappings, choices: :custom_dropdown_choices
      # custom_date mappings: :custom_date_mappings
    end
  end
end
