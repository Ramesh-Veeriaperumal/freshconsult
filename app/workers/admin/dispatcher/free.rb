module Admin::Dispatcher
  class Free < Worker

    sidekiq_options :queue => :free_dispatcher, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end