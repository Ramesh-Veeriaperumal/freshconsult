module Admin::Dispatcher
  class Worker

    include Sidekiq::Worker 

    sidekiq_options :queue => :dispatcher, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform args
      disptchr = Helpdesk::Dispatcher.new(args)
      disptchr.execute
    end
  end
end