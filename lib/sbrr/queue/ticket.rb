module SBRR
  module Queue
    class Ticket < Base

      attr_accessor :object_display_id

      def pop
        @operation = :dequeue
        MAX_RETRIES.times do |time|
          top_object, _score = top
          return if top_object.nil?
          @object_display_id = top_object
          result = zrem_multi_exec
          if result.is_a?(Array) && result[1].present?
            SBRR.log "pop time, attempt: #{time}, popped ticket #{top_object} " 
            return top_object 
          end
        end
      end

      def key
        SKILL_BASED_TICKETS_SORTED_SET % 
          {:account_id => account_id, :group_id => group_id, :skill_id => skill_id }
      end

      def lock_key _member = member
        SKILL_BASED_TICKETS_LOCK_KEY % {:account_id => account_id, :ticket_id => _member }
      end

      private

        def member
          @object_display_id || @object.display_id
        end

        def score
          @score ||= score_calculator.score object, old_score
        end

        def lock_key_value
          score
        end

    end
  end
end
