module Admin::Dispatcher
  class Trial < Worker

    sidekiq_options :queue => :trial_dispatcher, :retry => 0, :failures => :exhausted
  end
end