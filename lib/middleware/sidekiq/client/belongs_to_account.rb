module Middleware
  module Sidekiq
    module Client
      class BelongsToAccount
        class ::AccountMismatch < RuntimeError
        end

        IGNORE = [].freeze

        def initialize(options = {})
          @ignore = options.fetch(:ignore, IGNORE)
        end

        def call(worker, msg, _queue, _redis_pool)
          # original queue is used to print in sidekiq_bb.log to see which queue takes more time. We can remove it once its stable
          unless msg['reroute']
            msg['message_uuid'] = Thread.current[:message_uuid]
            unless @ignore.include?(worker.to_s) || worker.to_s.start_with?('CronWebhooks::')
              if msg['account_id'] && Account.current.try(:id) && msg['account_id'] != Account.current.id
                Rails.logger.debug "Account ID mismatch #{Account.current.id} #{msg.inspect}"
                NewRelic::Agent.notice_error(::AccountMismatch, description: "Account ID mismatch, Account.current.id :: #{Account.current.id} msg[account_id] :: #{msg['account_id']} ", job_id: Thread.current[:message_uuid], params: msg)
                raise ::AccountMismatch
              end
              msg['account_id'] ||= ::Account.current.id
              msg['shard_name'] ||= ShardMapping.fetch_by_account_id(::Account.current.id).try(:shard_name)
            end
          end
          yield
          # rescue Exception => e
          #   NewRelic::Agent.notice_error(e)
        end
      end
    end
  end
end
