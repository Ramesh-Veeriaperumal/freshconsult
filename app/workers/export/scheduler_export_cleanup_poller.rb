class Export::SchedulerExportCleanupPoller
  include Shoryuken::Worker
  shoryuken_options queue: ::SQS[:fd_scheduler_export_cleanup_queue], auto_delete: true,
                    body_parser: :json

  def perform(sqs_msg, args)
    begin
      Rails.logger.info "Processing #{args['scheduler_type']} id :::: #{args['export_id']}"
      @export = Account.current.data_exports.where(id: args['export_id']).first
      @export.destroy if @export.present?
      return true
    rescue Exception => e
      Rails.logger.error "Export Cleanup scheduler poller exception - #{e.message} - #{e.backtrace.first}"
      NewRelic::Agent.notice_error(e, { arguments: args })
      raise e
    end
  end
 end
