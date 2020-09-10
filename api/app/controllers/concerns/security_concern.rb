# frozen_string_literal: true

module SecurityConcern
  extend ActiveSupport::Concern
  include Admin::SecurityConstants
  include FDPasswordPolicy::Constants

  # **------------ Whitelisted IP -------------**

  def assign_whitelisted_ip_settings(settings = cname_params[:whitelisted_ip])
    whitelisted_ip.load_ip_info(request.env['CLIENT_IP'])
    whitelisted_ip.enabled = settings[:enabled] if settings.key?(:enabled)
    whitelisted_ip.attributes = settings if whitelisted_ip.enabled
  end

  def whitelisted_ip
    @whitelisted_ip ||= (@item.whitelisted_ip || @item.build_whitelisted_ip)
  end

  # **------------ Notification emails --------------**

  def assign_notification_emails_settings(emails = cname_params[:notification_emails])
    @item.account_configuration.contact_info[:notification_emails] = emails
  end

  # **------------ Password policy ------------** #
  POLICY_USER_TYPES.each do |policy_type|
    key = "#{policy_type}_password_policy"
    define_method "assign_#{key}_settings" do |value = cname_params[key.to_sym]|
      policy = fetch_password_policy(policy_type)
      set_advanced_policies(policy, value)
    end
  end

  def set_advanced_policies(password_policy, conditions)
    selected, rejected = conditions.keys.partition { |key| conditions[key].present? }
    current_policies = (password_policy.policies | selected).map(&:to_sym) - rejected.map(&:to_sym)
    current_configs = password_policy.configs.merge(formatted_configs(conditions.slice(*CONFIG_REQUIRED_POLICIES)))
    password_policy.attributes = { policies: current_policies, configs: current_configs }
  end

  def fetch_password_policy(type)
    @item.safe_send("#{type}_password_policy") || @item.safe_send("build_#{type}_password_policy")
  end

  def formatted_configs(configs)
    configs.each_pair { |k, v| configs[k] = v.to_s if v.present? }
  end
end
