class Admin::Sandbox::Account < ActiveRecord::Base
  self.table_name = "admin_sandbox_accounts"
  belongs_to_account

  include Binarize

  before_save :set_default_values

  STATUSES = [
    [:live,     'Live',     1],
    [:stopped,  'Stopped',  2]
  ]

  STATUS_KEYS_BY_TOKEN = Hash[*STATUSES.map { |i| [i[0], i[2]] }.flatten]

  # XXX TODO - read from constant
  CONFIGS   = [:agent_password_policy, :contact_password_policy, :features, :all_va_rules, :all_supervisor_rules, :all_observer_rules, :scn_automations, :ticket_field_def, :ticket_fields, :agents, :groups, :roles, :tags, :ticket_filters, :business_calendar, :canned_response_folders, :sla_policies, :ticket_templates, :email_notifications, :contact_form, :company_form, :custom_surveys, :user_roles, :status_groups, :products, :helpdesk_permissible_domains]

  binarize :config, flags: CONFIGS

  def set_default_values
    self.status ||= STATUS_KEYS_BY_TOKEN[:stopped]

    if self.config.blank?
      CONFIGS.each do |c|
        self.send("mark_#{c}_config")
      end
    end
  end

  def sync_enabled_configs
    self.in_config.map(&:to_s)
  end

  def active?
    self.status == STATUS_KEYS_BY_TOKEN[:live]
  end
end
