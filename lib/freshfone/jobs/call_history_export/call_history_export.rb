class Freshfone::Jobs::CallHistoryExport::CallHistoryExport
  extend Resque::AroundPerform
  
  @queue = 'data_export_queue'

  def self.perform(export_params)
    Rails.logger.info "CallHistoryExport ::: Initializing worker"
    begin
      Freshfone::Jobs::CallHistoryExport::CallHistoryExportWorker.new(export_params).perform
    rescue Exception => e
      Rails.logger.error "Error initializing worker:\n#{e.backtrace.join('\n')}"
    end
  end
end