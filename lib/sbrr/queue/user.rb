module SBRR
  module Queue
    class User < Base

      def pop_if_within_capping_limit _user, _capping_limit, relevant_queues
        @object     = _user
        @operation  = :incr
        MAX_RETRIES.times do |time|
          SBRR.log "pop_if_within_capping_limit, attempt: #{time},  user_id :#{_user.id} pop_if_within_capping_limit  #{_capping_limit}" 
          watch
          top_object, score = self.top
          #deciding which user is outside, bcoz the aggregator fetching the queues should be outside
          if _user.id != top_object.to_i || no_of_tickets_assigned(score) >= _capping_limit#changed before watching
            SBRR.log " returning as top object has changed" 
            return
          end
          
          scores = relevant_queues.map do |queue| #prefetching scores
            queue.object = _user
            "%016d" % queue.zscore.to_i
          end
          SBRR.log "#{scores.inspect}"

          result = $redis_round_robin.multi do |m|
            relevant_queues.each_with_index do |queue, index| #updating scores in relevant queues
              queue.check_and_set_via_multi m, _user, scores[index], @operation
            end
            self.set_via_multi m
          end

          scores = relevant_queues.map do |queue|
            "%016d" % queue.zscore.to_i
          end
          SBRR.log "#{scores.inspect}" 

          return top_object if result.is_a?(Array) && result.last == 'OK'
        end
      end

      def key
        SKILL_BASED_USERS_SORTED_SET % 
          {:account_id => account_id, :group_id => group_id, :skill_id => skill_id }
      end

      def lock_key _member = member
        SKILL_BASED_USERS_LOCK_KEY % 
          {:account_id => account_id, :group_id => group_id, 
            :user_id => _member}
      end

      private

        def no_of_tickets_assigned(score)
          ScoreCalculator::User.new(nil, score).old_assigned_tickets_in_group
        end

        def score
          @score ||= score_calculator.score object, skill_id, operation, old_score
        end
      public
        def lock_key_value
          score_calculator.operated_assigned_tickets_in_group  
        end

    end
  end
end
