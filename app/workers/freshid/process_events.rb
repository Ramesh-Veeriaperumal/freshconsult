class Freshid::ProcessEvents < BaseWorker 
  include Freshid::CallbackMethods
  sidekiq_options queue: :freshid_events, retry: 0,  failures: :exhausted

  def perform(args)
    process_events args
  end
end
