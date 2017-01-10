module SBRR
  module Synchronizer
    module UserUpdate
      class Base

        attr_reader :user, :group, :skill, :skills

        def initialize(user, options = {})
          @user  = user
          @group = options[:group]
          @skill = options[:skill]
          @skills= options[:skills] #agent destroy
        end

        def enqueue_in_relevant_queues
          perform_in_queues queues, :enqueue_object_with_lock, user
        end

        def dequeue_from_relevant_queues
          perform_in_queues queues, :dequeue_object_with_lock, user
        end

        def queue_details
          [user, {:group => group, :skill => skill, :skills => skills}]
        end

        def queues
          queue_aggregator(*queue_details).relevant_queues
        end

        private

          def perform_in_queues _user_queues, operation, _user
            _user_queues.each{ |_user_queue| _user_queue.send(operation, _user) }
          end

      end
    end
  end
end
