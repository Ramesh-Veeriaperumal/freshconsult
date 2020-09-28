# frozen_string_literal: true

module Dashboard::Custom::OmniWidgetConfigValidationMethods
  include Dashboard::Custom::WidgetConfigValidationMethods
  include Dashboard::Custom::CustomDashboardConstants

  FRESHCALLER_TIME_TYPES = {
    1 => 'Last 1 Hour',
    2 => 'Today'
  }.freeze

  def valid_config?(options)
    return { feature: 'omni_channel_team_dashboard' } unless Account.current.omni_channel_team_dashboard_enabled?

    @config_errors = []
    self::CONFIG_FIELDS.each do |field|
      @config_errors << field.to_s unless safe_send("validate_#{field}", options[:source], options[field])
    end
    @config_errors.empty? ? true : { fields: @config_errors }
  end

  def validate_queue_id(source, queue_id)
    source == SOURCES[:freshcaller] ? queue_id.present? && queue_id >= ALL_QUEUES : queue_id.blank?
  end

  def validate_time_type(source, time_type)
    source == SOURCES[:freshcaller] ? FRESHCALLER_TIME_TYPES[time_type.to_i].present? : time_type.blank?
  end

  def validate_group_ids(source, group_ids)
    source == Dashboard::Custom::CustomDashboardConstants::SOURCES[:freshchat] ? group_ids.present? : group_ids.blank?
  end
end
