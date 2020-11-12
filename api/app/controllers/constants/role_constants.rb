module RoleConstants
  BULK_UPDATE_FIELDS = %w(options).freeze
  ALLOWED_BULK_UPDATE_OPTIONS = [:privileges].freeze
  DEFAULT_ROLE_UPDATABLE_PRIVILEGES = {
    'Supervisor' => ['manage_availability', 'view_admin'],
    'Administrator' => ['manage_availability', 'view_admin'],
    'Account Administrator' => ['manage_availability', 'view_admin']
  }.freeze
  PRIVILEGE_DEPENDENCY_MAP = {
    view_admin: [
      :manage_users, :manage_availability, :manage_skills, :manage_tags,
      :manage_canned_responses, :manage_dispatch_rules, :manage_supervisor_rules,
      :manage_scenario_automation_rules, :manage_email_settings, :manage_ticket_templates,
      :manage_bots, :manage_account, :manage_requester_notifications, :manage_proactive_outreaches
    ],
    view_reports: [:export_reports, :manage_dashboard],
    view_contacts: [:manage_contacts, :manage_companies, :manage_segments, :delete_contact, :delete_company, :export_customers],
    view_forums: [:manage_forums, :create_topic, :delete_topic],
    view_solutions: [:publish_solution, :delete_solution, :manage_solutions],
    manage_tickets: [:reply_ticket, :forward_ticket, :edit_note, :edit_conversation,
     :merge_or_split_ticket, :edit_ticket_properties, :view_time_entries, :delete_ticket, :export_tickets],

    create_topic: [:edit_topic],
    edit_ticket_properties: [:edit_ticket_skill, :view_secure_field],
    view_time_entries: [:edit_time_entries],
    view_secure_field: [:edit_secure_field]
  }.freeze
  BULK_UPDATE_METHOD = 'bulk_update'.freeze
  BULK_VALIDATION_CLASS = 'RoleBulkUpdateValidation'.freeze
  VIEW_ADMIN_PRIVILEGE = :view_admin.freeze
  RESTRICTED_PRIVILEGES = [:manage_account].freeze
  QMS_ADMIN_PRIVILEGES = [:manage_scorecards, :manage_teams, :view_scores].freeze
  QMS_AGENT_PRIVILEGES = [:view_scores, :view_scorecards].freeze
  MAX_ROLES_LIMIT = 100
end.freeze