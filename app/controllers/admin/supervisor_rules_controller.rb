class Admin::SupervisorRulesController < Admin::VaRulesController
  
  before_filter :check_supervisor_feature

  def ticket_field_filters_for_automations
    fields = current_account.ticket_fields.non_encrypted_custom_fields.preload(:flexifield_def_entry).all
    fields.reject do |tf|
      TicketFieldData::NEW_DROPDOWN_COLUMN_NAMES.include?(tf.flexifield_def_entry.flexifield_name) ||
        TicketFieldData::NEW_CHECKBOX_COLUMN_NAMES.include?(tf.flexifield_def_entry.flexifield_name)
    end
  end

  def ticket_field_actions_for_automations
    fields = current_account.ticket_fields.non_encrypted_custom_fields.all.reject(&:fsm_reserved_custom_field?)
    fields.reject do |tf|
      TicketFieldData::NEW_DROPDOWN_COLUMN_NAMES.include?(tf.flexifield_def_entry.flexifield_name) ||
        TicketFieldData::NEW_CHECKBOX_COLUMN_NAMES.include?(tf.flexifield_def_entry.flexifield_name)
    end
  end

  protected
  
    def scoper
      current_account.supervisor_rules
    end
    
    def all_scoper
      current_account.all_supervisor_rules
    end
    
    def human_name
      "Supervisor rule"
    end

    def get_event_performer
      []
    end

    def check_supervisor_feature
      non_covered_admin_feature unless current_account.supervisor_enabled?
    end
end
