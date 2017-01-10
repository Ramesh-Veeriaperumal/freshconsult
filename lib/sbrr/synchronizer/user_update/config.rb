module SBRR
  module Synchronizer
    module UserUpdate
      class Config < Base #to sync agent_groups && user_skills records

        def sync action
          case action
          when :create
            enqueue_in_relevant_queues
          when :update
            enqueue_in_relevant_queues # for user_skill - rank updates, zadd as well updates the score
          when :destroy
            dequeue_from_relevant_queues
          end
        end

        private   

          def queue_aggregator user, options
            QueueAggregator::User.new(user, options)
          end
          
      end
    end
  end
end
