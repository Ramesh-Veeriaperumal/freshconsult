require 'helpdesk_activities/activity_types'
class ExportController < ApiApplicationController
  before_filter :feature_check, :check_privilege, :validate_params

  def ticket_activities
    @client = thrift_client
    export_param = construct_param
    activities_file_url export_param
    parse_response response
  rescue Exception => e
    Rails.logger.debug e.message
    raise
  ensure
    $activities_export_thrift_transport.close
  end

  private

    def feature_check
      render_request_error(:require_feature, 403, feature: 'activity export'.titleize) unless Account.current.ticket_activity_export_enabled?
    end

    def check_privilege
      success = super
      render_request_error(:access_denied, 403) if success && User.current && !User.current.privilege?(:manage_account)
    end

    def validate_params
      @export = ExportValidation.new(params)
      render_custom_errors(@export, true) unless @export.valid?
    end

    def thrift_client
      $activities_export_thrift_transport.open
      ::HelpdeskActivities::TicketActivitiesExport::Client.new($activities_export_thrift_protocol)
    end

    def construct_param
      act_param = ::HelpdeskActivities::ActivityExportRequest.new
      act_param.account_id = Account.current.id
      act_param.date = params[:created_at]
      act_param
    end

    def activities_file_url(export_param)
      @response = @client.get_activities_export_file(export_param)
    end

    def parse_response(_response)
      if @response.first.file_url
        @result = @response.collect do |r|
          {
            'created_at' => r.date,
            'url' => r.file_url
          }
        end
      else
        if @response.first.error_message == 'File not found'
          render_base_error(:file_not_found, 404)
          return
        end
        @export.errors[:created_at] << :invalid_value
        @export.error_options[:created_at] = { value: @response.first.date, prepend_msg: 'created at is an ', append_msg: ". #{@response.first.error_message}." }
        render_custom_errors(@export, true)
      end
    end
end
