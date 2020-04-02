module Admin::ServiceTaskDispatcher
  class Worker
    include Sidekiq::Worker

    sidekiq_options queue: :service_task_dispatcher, retry: 0, failures: :exhausted

    def perform(args)
      disptchr = Helpdesk::ServiceTaskDispatcher.new(args)
      disptchr.execute
    end
  end
end
