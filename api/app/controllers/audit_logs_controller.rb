class AuditLogsController < ApiApplicationController
  include AuditLog::CannedResponseFolderHelper
  include AuditLog::CannedResponseHelper
  include AuditLog::AuditLogHelper
  include AuditLog::SubscriptionHelper
  include AuditLog::AgentHelper
  include AuditLog::AutomationHelper
  include AuditLog::CompanyHelper
  include Admin::AutomationConstants
  include ContactsCompaniesConcern
  include AuditLog::AuditLogExportHelper
  include AuditLog::SolutionCategoryHelper
  include AuditLog::SolutionFolderHelper
  include AuditLog::SolutionArticleHelper

  around_filter :run_on_slave
  before_filter :validate_filter_params, only: [:export, :filter]
  before_filter :validate_export_limit, only: [:export]
  before_filter :load_data_export, only: [:export_s3_url]

  def filter
    filter_params = sanitize_filter_params
    enriched_data = enrich_response(HyperTrail::AuditLog.new(filter_params).fetch)
    @items = enriched_data[:data]
    response.api_meta = { next: enriched_data[:next] } if enriched_data[:next].present?
    response.api_root_key = :audit_log
  end

  def export
    export_params = sanitize_export_params
    Rails.logger.info "Api params for hyper trail #{export_params}"
    archived = params[:archived] ? params[:archived] : false
    export_params[:archived] = archived
    export_params[:action] = params[:action]
    resp = HyperTrail::AuditLog.new(export_params).trigger_export
    Rails.logger.info "Job_id : #{resp['job_id']}"
    if resp[:data]
      @items = { response: resp[:data].body.to_json }
      return
    end
    resp.merge!({receive_via: params[:receive_via], export_format: params[:export_format], archived: archived})
    HyperTrail::AuditLog.new(resp).retrive_export_data if resp['job_id']
    if params[:receive_via] == AuditLogConstants::RECEIVE_VIA[0]
      @items = { status: 'generating export' }
    elsif params[:receive_via] == AuditLogConstants::RECEIVE_VIA[1]
      url = "#{request.url}/#{resp['job_id']}"
      @items = { response: url }
    end
  end

  def export_s3_url
    resp = fetch_export_details
    @items = if resp[:status] == :completed
               { url: resp[:download_url] }
             else
               { export_status: resp[:status] }
             end
  end

  def event_name
    method_name = AuditLogConstants::AUTOMATION_RULE_METHODS[params[:type]]
    if method_name.present?
      name = AuditLogConstants::EVENT_TYPES_NAME[params[:type]] || :name
      @items = current_account.safe_send(method_name).map do |model|
        { name: model.safe_send(name), id: model.id }
      end
    end
  end

  private

    def validate_filter_params
      validate_export_params if params[:action] == 'export'
      audit_log_validation = AuditLogValidation.new(params, nil, false)
      if audit_log_validation.invalid?
        render_errors(audit_log_validation.errors,
                      audit_log_validation.error_options)
      end
    end

    def validate_export_params
      params[cname].permit(*AuditLogConstants::EXPORT_PARAMS)
      if params[cname][:filter]
        params[cname][:filter].each do |filter_sets|
          filter_sets.each do |filter_set|
            filter_sets_key = filter_set.to_sym if filter_set.include? 'filter_set'
            filter_set_value = params[cname][:filter][filter_sets_key]
            next if filter_set_value.blank?
            filter_set_value.permit(*AuditLogConstants::EXPORT_FILTER_SET_PARAMS)
          end
        end
      end
    end

    def validate_export_limit
      if DataExport.audit_log_export_limit_reached?
        render_request_error_with_info(:audit_log_export, 429)
      end
    end

    def load_data_export
      fetch_data_export_item(AuditLogConstants::EXPORT_TYPE)
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
      export_filter_params[:filters] = clean_export_filters if params[:filter]
      before = Date.parse params[:to]
      export_params[:since] = DateTime.parse(params[:from]).beginning_of_day.strftime('%Q').to_i # changing to epoch
      export_params[:before] = if before == Time.zone.today || before > Time.zone.today
                                 Time.zone.now.to_i * 1000
                               else
                                DateTime.parse(params[:to]).end_of_day.strftime('%Q').to_i
                               end
      export_params[:cond] = construct_export_condition if params[:condition]
      export_params.merge!(export_filter_params) if export_filter_params
      export_params
    end

    def clean_export_filters
      export_filter_params = {}
      export_filter_set_params = filter_set_params(params[:filter], {})
      AuditLogConstants::EXPORT_FILTER_PARAMS.each do |query_param|
        value = params[:filter][query_param]
        next if value.blank?

        if value.include? 'delete'
          ind = value.index('delete')
          value[ind] = 'destroy'
        end
        key = query_param == :performed_by ? :actor : query_param
        value.map!(&:to_s) if key == :actor
        export_filter_set_params.merge!(key => value)
      end
      export_filter_params[:filters] = export_filter_set_params
      export_filter_params[:filters]
    end

    def construct_export_condition
      params[:condition] = params[:condition].split(' ')[1..-1].join(' ') if params[:condition].split.first == AuditLogConstants::CONDITION_UPPER_CASE
      params[:condition].sub!('performed_by', 'actor') if params[:condition].include? 'performed_by'
      conditions = params[:condition] if params[:condition]
      conditions
    end
end
