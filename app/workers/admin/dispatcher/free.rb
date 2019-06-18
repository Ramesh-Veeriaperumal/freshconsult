module Admin::Dispatcher
  class Free < Worker

    sidekiq_options :queue => :free_dispatcher, :retry => 0, :failures => :exhausted
  end
end