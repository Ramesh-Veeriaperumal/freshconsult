module Middleware
  module Sidekiq
    module Client
      class BelongsToAccount
  
        class ::AccountMismatch < Exception
        end

        IGNORE = []

        def initialize(options = {})
          @ignore = options.fetch(:ignore, IGNORE)
        end

        def call(worker, msg, queue,redis_pool)
          #original queue is used to print in sidekiq_bb.log to see which queue takes more time. We can remove it once its stable
          original_queue = msg['queue']
          msg['queue'] = queue_from_classification(msg['queue'])
          msg['original_queue'] = original_queue
          msg['message_uuid'] = Thread.current[:message_uuid]
          unless @ignore.include?(worker.to_s) || worker.to_s.start_with?('CronWebhooks::')
            if msg['account_id'] && Account.current.try(:id) && msg['account_id'] != Account.current.id
              Rails.logger.debug "Account ID mismatch #{Account.current.id} #{msg.inspect}"
              NewRelic::Agent.notice_error(::AccountMismatch, description: "Account ID mismatch, Account.current.id :: #{Account.current.id} msg[account_id] :: #{msg['account_id']} ", job_id: Thread.current[:message_uuid], params: msg)
              raise ::AccountMismatch
            end
            msg['account_id'] ||= ::Account.current.id
          end
          yield
          # rescue Exception => e
          #   NewRelic::Agent.notice_error(e)
        end

        def queue_from_classification(queue_name)
          #cache locally for 5 mins to avoid redis calls for every push
          #will remove this code once its stable
          members = []
          begin
            members = Rails.cache.fetch("SIDEKIQ_CLASSIFICATION",  expires_in: 5.minutes) do
              $redis_others.smembers("SIDEKIQ_QUEUE_CLASSIFICATION_LIST")
            end

            dedicated_list = Rails.cache.fetch("DEDICATED_SIDEKIQ_QUEUE",  expires_in: 5.minutes) do
              $redis_others.smembers("DEDICATED_SIDEKIQ_QUEUE_LIST")
            end

            if Account.current && dedicated_list.include?(Account.current.id.to_s)
              members.include?(queue_name) ? "#{SIDEKIQ_CLASSIFICATION_MAPPING[queue_name]}_#{Account.current.id}" : queue_name
            else
              members.include?(queue_name) ? SIDEKIQ_CLASSIFICATION_MAPPING[queue_name] : queue_name
            end
          rescue Exception => e
            Rails.logger.info "Error in fetching classification... #{e.message}"
            members.include?(queue_name) ? SIDEKIQ_CLASSIFICATION_MAPPING[queue_name] : queue_name
          end
        end

      end
    end
  end
end
