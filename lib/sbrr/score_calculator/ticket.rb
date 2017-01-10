module SBRR
  module ScoreCalculator

    class Ticket < Base

      def score _member, _old_score = nil
        @score ||= begin
          @member    = _member
          @old_score = _old_score
          old_score || member.created_at.to_i
        end
      end

    end

  end
end
