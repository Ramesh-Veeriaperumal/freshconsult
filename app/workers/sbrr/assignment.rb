module SBRR
  class Assignment < BaseWorker

    sidekiq_options queue: :sbrr_assignment,
                    retry: 0,
                    failures: :exhausted

    def perform args
      args["options"]["jid"] = self.jid
      ::SBRR::Execution.new(args).execute
    end

  end
end
