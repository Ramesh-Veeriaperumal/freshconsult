module Admin::Dispatcher
  class Active < Worker

    sidekiq_options :queue => :active_dispatcher, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end