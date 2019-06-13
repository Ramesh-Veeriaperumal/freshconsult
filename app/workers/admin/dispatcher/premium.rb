module Admin::Dispatcher
  class Premium < Worker

    sidekiq_options :queue => :premium_dispatcher, :retry => 0, :failures => :exhausted
  end
end