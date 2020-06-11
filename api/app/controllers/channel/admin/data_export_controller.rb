class Channel::Admin::DataExportController < ApiApplicationController
  include ChannelAuthentication
  include Silkroad::Constants::Ticket
  include Silkroad::Constants::Base
  include Export::Util
  skip_before_filter :check_privilege, if: :skip_privilege_check?
  before_filter :channel_client_authentication

  def update
    Rails.logger.error("Silkroad trace_id is :: #{request.headers['X-Client-ID']}")
    silkroad_export_validation = Channel::SilkroadExportValidation.new(params)
    if silkroad_export_validation.valid?
      save_and_send_mail(params[:status])
      head 200
    else
      head 400
    end
  end

  private

    def skip_privilege_check?
      channel_source?(:silkroad)
    end

    def scoper
      current_account.data_exports
    end

    def validate_params
      true
    end

    def load_object(items = scoper)
      @data_export = items.where(job_id: params[:job_id]).last
    end

    def save_and_send_mail(job_status)
      @export_user = @data_export.user
      if @data_export.status == DataExport::EXPORT_STATUS[:started]
        if job_status == SILKROAD_EXPORT_STATUS[:failed]
          @data_export.failure!('silkroad failure')
          Rails.logger.info 'Silkroad :: Export Marked Failure!'
          DataExportMailer.send_later(:export_failure, email_params) if current_account.launched?(:silkroad_export)
        else
          @data_export.completed!
          if current_account.launched?(:silkroad_export)
            DataExportMailer.send_later(:ticket_export, email_params)
            Rails.logger.info 'Export Marked Success & Sent Success Mail'
          else
            Rails.logger.info 'Silkroad Shadow Mode :: Export Marked Success'
            calculate_export_performance
          end
        end
      else
        Rails.logger.info "Not Updated as the export status not in Started state. Status :: #{DataExport::EXPORT_STATUS.key(@data_export.status)}"
      end
    end

    def calculate_export_performance
      helpkit_export_id = @data_export.export_params[:helpkit_export_id]
      helpkit_data_export = @export_user.data_exports.find(helpkit_export_id)
      time_taken = helpkit_data_export.updated_at - helpkit_data_export.created_at
      Rails.logger.info "Export Performance :: Helpkit :: #{time_taken} & Silkroad :: #{request.headers['X-Time-Taken']}"
    end

    def email_params
      {
        user: @export_user,
        domain: current_account.full_domain,
        url: hash_url(current_account.full_domain),
        export_params: @data_export.export_params,
        type: DataExport::EXPORT_NAME_BY_TYPE[@data_export.source]
      }
    end
end
