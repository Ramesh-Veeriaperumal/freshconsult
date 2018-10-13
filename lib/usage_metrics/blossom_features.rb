module UsageMetrics::BlossomFeatures
  include UsageMetrics::SproutFeatures

  DEFAULT_TICKET_VIEWS_COUNT = 4
  MULTIPLE_EMAILS_COUNT = 1

  def sla_management(args)
    args[:account].sla_policies.active.any? do |sla_policy|
      sla_policy.escalations[:reminder_response].present? || 
        sla_policy.escalations[:response].present?
    end
  end

  def supervisor(args)
    args[:account].supervisor_rules.exists?
  end

  def custom_ticket_fields(args)
    args[:account].ticket_fields_from_cache.any?{ |field| !field.default }
  end

  def custom_contact_fields(args)
    args[:account].contact_form.contact_fields_from_cache.any?(&:custom_field?)
  end

  def custom_company_fields(args)
    args[:account].company_form.company_fields_from_cache.any?(&:custom_field?)
  end

  def custom_ticket_views(args)
    args[:account].ticket_filters.select(:id).limit(DEFAULT_TICKET_VIEWS_COUNT + 1).
      length > DEFAULT_TICKET_VIEWS_COUNT
  end

  def occasional_agent(args)
    args[:account].agents.occasional_agents.exists?
  end

  def create_observer(args)
    args[:account].observer_rules_from_cache.present?
  end

  def multiple_emails(args)
    args[:account].email_configs.select(:id).limit(2).length > MULTIPLE_EMAILS_COUNT
  end

  def timesheets(args)
    args[:account].all_time_sheets.created_in_last_twenty_days.reorder(:id).exists?
  end
  
  def surveys(args)
    args[:account].active_custom_survey_from_cache.present?
  end
end