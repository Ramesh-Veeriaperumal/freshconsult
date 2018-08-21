Marginalia::Comment.components = [:request_id, :jid, :sid]

module Marginalia
  module Comment
    def self.jid
      if marginalia_job.present?
        marginalia_job_keys[:jid]
      end
    end

    # Front request_id or parent job_id which generated the job.
    def self.sid
      if marginalia_job.present?
        value = marginalia_job_keys[:message_uuid]
        value.kind_of?(Array) ? value.first : value.inspect
      end
    end

    def self.marginalia_job_keys
      marginalia_job.symbolize_keys
    end
  end

  class SidekiqInstrumentation
    def call(worker, msg, queue)
        Marginalia::Comment.update_job! msg
        yield
      ensure
        Marginalia::Comment.clear_job!
    end
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Marginalia::SidekiqInstrumentation
  end
end

# Add Marginalia support for Ember and public API. For non metal the hook is already present in Marginalia Gem Railtie.
ActionController::Metal.send(:include, Marginalia::ActionControllerInstrumentation)
