class Tickets::Export::TicketsExport < BaseWorker
  include Sidekiq::Worker
  include Silkroad::Export::FeatureCheck
  sidekiq_options queue: :tickets_export_queue, retry: 0, failures: :exhausted

  def perform(export_params)
    export_params.symbolize_keys!
    if Account.current.launched?(:silkroad_export) && send_to_silkroad?(export_params)
      Silkroad::Export::Ticket.new.create_job(export_params)
    else
      Export::Ticket.new(export_params).perform
    end
  end
end
