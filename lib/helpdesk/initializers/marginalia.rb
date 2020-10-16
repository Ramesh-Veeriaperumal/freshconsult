# frozen_string_literal: true

Marginalia::Comment.components = [:request_id, :jid, :sid, :replica]

module Marginalia
  module Comment
    REPLICA_STRINGS = {
      primary: 'primary',
      replica: 'replica'
    }.freeze

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

    def self.replica
      on_replica = request_id ? ActiveRecord::Base.current_shard_selection.on_slave? : Thread.current[:replica]
      on_replica ? REPLICA_STRINGS[:replica] : REPLICA_STRINGS[:primary]
    end

    def self.marginalia_job_keys
      marginalia_job.symbolize_keys
    end
  end
end

Marginalia::SidekiqInstrumentation.enable!
