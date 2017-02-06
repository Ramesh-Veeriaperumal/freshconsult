module SBRR
  module Synchronizer
    module UserUpdate
      class Toggle < Base #to sync agent availability toggle && group RR toggle

        def sync ready_for_round_robin
          if ready_for_round_robin
            enqueue_in_relevant_queues
          else
            dequeue_from_relevant_queues
          end
        end

        private

          def queue_aggregator user, options
            QueueAggregator::User.new(user, options.except(:skill)) #intentionally leaving out skill
          end
          
      end
    end
  end
end
