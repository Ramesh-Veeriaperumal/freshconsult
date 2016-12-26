module SBRR
  module QueueAggregator
    class Ticket < Base

      private

        def queue _group_id, _skill_id, _score_calculator
          SBRR::Queue::Ticket.new(account_id, _group_id, _skill_id, _score_calculator)
        end

        def score_calculator group
          ScoreCalculator::Ticket.new(group)
        end

    end
  end
end
