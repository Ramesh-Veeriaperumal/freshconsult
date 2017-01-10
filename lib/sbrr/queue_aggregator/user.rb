module SBRR
  module QueueAggregator
    class User < Base

      private
        
        def queue _group_id, _skill_id, _score_calculator
          SBRR::Queue::User.new(account_id, _group_id, _skill_id, _score_calculator)
        end

        def score_calculator group
          ScoreCalculator::User.new(group)
        end

    end
  end
end
