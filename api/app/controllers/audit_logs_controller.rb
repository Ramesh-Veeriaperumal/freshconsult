class AuditLogsController < ApiApplicationController
  include AuditLog::AuditLogHelper
  include AuditLog::SubscriptionHelper
  include AuditLog::AgentHelper
  include AuditLog::AutomationHelper

  before_filter :validate_filter_params

  def filter
    filter_params = sanitize_filter_params
    enriched_data = enrich_response(HyperTrail::AuditLog.new(filter_params).fetch)
    @items = enriched_data[:data]
    response.api_meta = { next: enriched_data[:next] } if enriched_data[:next].present?
    response.api_root_key = :audit_log
  end

  def export; end

  def event_name
    method_name = AuditLogConstants::AUTOMATION_RULE_METHODS[params[:type]]
    if method_name.present?
      @items = current_account.safe_send(method_name).map do |rule|
        { name: rule.name, id: rule.id }
      end
    end
  end

  private

    def validate_filter_params
      audit_log_validation = AuditLogValidation.new(params, nil, false)
      if audit_log_validation.invalid?
        render_errors(audit_log_validation.errors,
                      audit_log_validation.error_options)
      end
    end

    def sanitize_filter_params
      self.params = params.symbolize_keys
      Rails.logger.info "Api params for hyper trail #{params.inspect}"
      clean_filter_params
    end

    def fetch_agent_id(user_id)
      Account.current.users.find_by_id(user_id).agent.id rescue nil
    end

    def clean_filter_params
      filter_params = {}
      AuditLogConstants::FILTER_PARAMS.each do |query_param|
        value = params[query_param]
        next if value.blank?
        key = query_param == :agent ? :actor : query_param
        value = fetch_agent_id(value) if key == :agent_id
        filter_params.merge!(key == :time ? { since: value[:from], before: value[:to] } : { "#{key}": value })
      end
      Rails.logger.info "Query params for hyper trail#{filter_params.inspect}"
      filter_params
    end
end
