class AuditLogsController < ApiApplicationController
  include AuditLog::AuditLogHelper
  include AuditLog::SubscriptionHelper
  include AuditLog::AgentHelper
  include AuditLog::AutomationHelper
  include Admin::AutomationConstants

  around_filter :run_on_slave
  before_filter :validate_filter_params

  def filter
    filter_params = sanitize_filter_params
    enriched_data = enrich_response(HyperTrail::AuditLog.new(filter_params).fetch)
    @items = enriched_data[:data]
    response.api_meta = { next: enriched_data[:next] } if enriched_data[:next].present?
    response.api_root_key = :audit_log
  end

  def export
    export_params = sanitize_export_params
    validate_export_params_delegator(export_params)
    Rails.logger.info "Api params for hyper trail #{export_params}"
    resp = HyperTrail::AuditLog.new(export_params).fetch_job_id
    render_errors(resp[:data]) if resp[:data]
    HyperTrail::AuditLog.new(resp).trigger_export
  end

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

    def validate_export_params_delegator(export_params)
      audit_log_delegator = AuditLogDelegator.new(export_params)
      if audit_log_delegator.invalid?
        render_errors(audit_log_delegator.errors.to_h, audit_log_delegator.error_options)
      end
    end

    def sanitize_filter_params
      self.params = params.symbolize_keys
      Rails.logger.info "Api params for hyper trail #{params.inspect}"
      clean_filter_params
    end

    def fetch_agent_id(user_id)
      Account.current.users.find_by_id(user_id).agent.id
    rescue StandardError
      nil
    end

    def clean_filter_params
      filter_params = {}
      AuditLogConstants::FILTER_PARAMS.each do |query_param|
        value = params[query_param]
        next if value.blank?
        key = query_param == :agent ? :actor : query_param
        value = fetch_agent_id(value) if key == :agent_id
        filter_params.merge!(key == :time ? { since: value[:from], before: value[:to] } : { key => value })
      end
      Rails.logger.info "Query params for hyper trail#{filter_params.inspect}"
      filter_params
    end

    def sanitize_export_params
      self.params = params.deep_symbolize_keys
      clean_export_params
    end

    def clean_export_params
      export_params = {}
      export_filter_params = {}
      if params[:filter]
        export_filter_params_temp = filter_set_params(params[:filter], {})
        AuditLogConstants::EXPORT_FILTER_PARAMS.each do |query_param|
          value = params[:filter][query_param]
          next if value.blank?
          
          if value.include? 'delete'
            ind = value.index('delete')
            value[ind] = 'destroy'
          end
          key = query_param == :performed_by ? :actor : query_param
          export_filter_params_temp.merge!(key => value)
        end
        export_filter_params[:filters] = export_filter_params_temp
      end

      since = Date.parse params[:from]
      before = Date.parse params[:to]
      zone = fetch_zone
      since = DateTime.new(since.year, since.month, since.day, 0, 0, 0, zone)
      export_params[:since] = since.strftime('%Q').to_i # changing to milliseconds
      export_params[:before] = before == Date.today ? Time.zone.now.to_i * 1000 : 
                              DateTime.new(before.year, before.month, before.day, 23, 59, 59, zone).strftime('%Q').to_i
      if params[:condition]
        params[:condition] = params[:condition].split(' ')[1..-1].join(' ') if params[:condition].split.first == 'AND'
        export_params[:conditions] = params[:condition] if params[:condition]
      end
      export_params.merge!(export_filter_params) if export_filter_params
      export_params
    end

    def filter_set_params(filter, export_filter_params_temp)
      type = []
      (1..6).each do |itr|
        filter_sets_key = "filter_set_#{itr}".to_sym
        filter_set_value = filter[filter_sets_key]
        next if filter_set_value.blank?

        rule_id = filter_set_value[:ids] if filter_set_value[:ids]
        if (AuditLogConstants::AUTOMATION_TYPES.include? filter_set_value[:entity][0]) && !rule_id.nil?
          rule_name = AuditLogConstants::ENTITY_HASH[filter_set_value[:entity][0]]
          rule_name = VAConfig::RULES_BY_ID[rule_name.to_i].to_s << '_id'
          export_filter_params_temp[rule_name] = rule_id
          params[:condition].sub!(filter_sets_key.to_s, rule_name) if params[:condition].include? filter_sets_key.to_s
        elsif filter_set_value[:entity][0] == 'agent' && !rule_id.nil?
          rule_name = 'agent_id'
          export_filter_params_temp[rule_name] = rule_id
          params[:condition].sub!(filter_sets_key.to_s, rule_name) if params[:condition].include? filter_sets_key.to_s
        else
          type = construct_type_array(params, filter_set_value, filter_sets_key)
        end
      end
      if type != []
        export_filter_params_temp[:type] = type
        params[:condition] << ' AND type'
      end
      export_filter_params_temp
    end

    def construct_type_array(params, filter_set_value, filter_sets_key)
      type = []
      [
        "AND #{filter_sets_key}",
        "OR #{filter_sets_key}",
        filter_sets_key.to_s,
        "#{filter_sets_key} AND",
        "#{filter_sets_key} OR"
      ].each do |key|
        if params[:condition].include?(key)
          params[:condition].slice!(key)
          type.push(replace_type_values(filter_set_value[:entity][0]))
        end
      end
      type
    end

    def replace_type_values(value)
      if AuditLogConstants::ENTITY_HASH.include? value
        id = AuditLogConstants::ENTITY_HASH[value]
        rule_name = VAConfig::RULES_BY_ID[id.to_i].to_s
      end
      value = rule_name unless rule_name.nil?
      value
    end

    def fetch_zone
      zone = User.current.time_zone
      zone = Time.now.in_time_zone(zone).utc_offset / 3600
      zone = zone > 0 ? '+#{zone}' : zone.to_s
      zone
    end
end
