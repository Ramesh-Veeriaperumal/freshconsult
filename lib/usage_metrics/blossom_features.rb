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

  def advanced_social(args)
    args[:account].twitter_handles_from_cache.count > 1 || args[:account].facebook_pages.count > 1
  end

  def todos_reminder_scheduler(args)
    last_reminder_scheduler = args[:account].reminders.scheduled.last
    last_reminder_scheduler.try(:created_at).try(:>, 30.days.ago).present?
  end

  def allow_auto_suggest_solutions(args)
    args[:account].features?(:auto_suggest_solutions) && args[:account].solution_articles.visible.exists?
  end

  def custom_status(args)
    args[:account].ticket_status_values_from_cache.reject(&:is_default).count > 2
  end

  def session_replay(args)
    args[:account].session_replay_enabled? && args[:account].account_additional_settings.freshmarketer_linked?
  end

  def custom_domain(args)
    args[:account].portals.pluck(:portal_url).any?
  end

  def contact_company_notes(args)
    args[:account].contact_notes.exists?
  end
end