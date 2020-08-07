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
end

Marginalia::SidekiqInstrumentation.enable!
