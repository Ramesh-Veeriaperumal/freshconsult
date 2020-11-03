module Middleware
  module Sidekiq
    module Server
      class BelongsToAccount

        IGNORE = []

        def initialize(options = {})
          @ignore = options.fetch(:ignore, IGNORE)
        end

        def call(worker, msg, queue)
          #Logic starts to add uuid and job id to log tags to debug
          begin
            log_tags = (msg.try(:[], 'message_uuid') || [])
            log_tags << msg["jid"]
            # First 3 and last 3/4 uuids in log
            log_tags.delete_at(log_tags_max_length / 2) if log_tags.length > log_tags_max_length
            Thread.current[:message_uuid] = log_tags
          rescue Exception => e
            log_tags = []
          end
          #Logic ends to add uuid and job id to log tags to debug

          Rails.logger.tagged(log_tags) do
            if !@ignore.include?(worker.class.name) && !worker.class.to_s.start_with?('CronWebhooks::')
              ::Account.reset_current_account
              account_id = msg['account_id']
              Sharding.select_shard_of(account_id) do
                account = ::Account.find(account_id)
                account.make_current
                yield
              end
            else
              yield
            end
          end
        rescue DomainNotReady => e
          Rails.logger.error "Just ignoring the DomainNotReady , #{e.inspect}, #{msg['account_id']}"
        rescue ShardNotFound => e
          Rails.logger.error "Ignoring ShardNotFound, #{e.inspect}, #{msg['account_id']}"
        rescue AccountBlocked => e
          Rails.logger.error "Ignore AccountBlocked, #{e.inspect}, #{msg['account_id']}"
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.error "Ignore ActiveRecord::RecordNotFound, #{e.inspect}, #{msg['account_id']}"
        rescue ::ActiveRecord::AdapterNotSpecified => e
          NewRelic::Agent.notice_error(e)
          # rescue Exception => e
          #   NewRelic::Agent.notice_error(e)
        rescue Account::RecordNotFound => e
          NewRelic::Agent.notice_error(e)
          Rails.logger.error "Account not found in shard :: #{e.message}, #{msg['account_id']}"
        ensure
          Thread.current[:message_uuid] = nil
        end

        def log_tags_max_length
          LoggerConstants::SIDEKIQ_LOG_TAGS_MAX_LENGTH
        end
      end
    end
  end
end