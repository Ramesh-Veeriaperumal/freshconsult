class Export::DataExport
  include Sidekiq::Worker

  sidekiq_options :queue => :data_export, :retry => 0, :backtrace => true,
                  :failures => :exhausted

  def perform(params)
    params.symbolize_keys!
    Helpdesk::ExportDataWorker.new(params).perform
  end
end