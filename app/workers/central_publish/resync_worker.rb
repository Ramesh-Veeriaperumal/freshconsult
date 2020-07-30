module CentralPublish
  class ResyncWorker < BaseWorker
    include CentralLib::CentralResync
    include CentralLib::CentralResyncRateLimiter

    sidekiq_options queue: :central_publish_resync, retry: 0, failures: :exhausted

    attr_accessor :relation_with_account

    def perform(args)
      @args = args.symbolize_keys!
      @relation_with_account = @args[:relation_with_account].to_sym

      configure_redis_and_execute(@args[:source]) do
        publish_entity_to_central
      end
    end

    def publish_entity_to_central
      return unless Account.current.respond_to?(@relation_with_account)

      Account.current.safe_send(@relation_with_account).sync_entity(@args)
    rescue StandardError => e
      Rails.logger.info "Publishing Entity FAILED => #{e.inspect}"
      NewRelic::Agent.notice_error(e, description: "Error publishing entity for Account: #{Account.current.id}, Service: #{@args[:source]}")
    end
  end
end
