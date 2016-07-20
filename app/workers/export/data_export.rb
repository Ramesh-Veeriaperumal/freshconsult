class Export::DataExport
  include Sidekiq::Worker

  sidekiq_options :queue => :data_export, :retry => 0, :backtrace => true,
                  :failures => :exhausted

  def perform(params)
  	TimeZone.set_time_zone
    params.symbolize_keys!
    Helpdesk::ExportDataWorker.new(params).perform
  end
end