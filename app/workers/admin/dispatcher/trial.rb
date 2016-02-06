module Admin::Dispatcher
  class Trial < Worker

    sidekiq_options :queue => :trial_dispatcher, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end