module SBRR
  module ScoreCalculator

    class Ticket < Base

      def score _member, _old_score = nil
        @score ||= begin
          @member    = _member
          @old_score = _old_score
          old_score || (Time.now.to_f * 1000000).to_i #support until year 2254
        end
      end

    end

  end
end
