class Freshid::V2::ProcessEvents < BaseWorker 
  sidekiq_options queue: :freshid_v2_events, retry: 0,  failures: :exhausted

  def perform(args)
    Freshid::V2::EventProcessor.new(args).process
  end
end
