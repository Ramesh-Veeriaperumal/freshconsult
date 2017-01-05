module SBRR
  module ScoreCalculator
    class Base

      attr_accessor :group, :old_score, :member

      def initialize _group, _old_score = nil
        @group     = _group #group will contain the config for score
        @old_score = _old_score
      end

      # max accurate score - 9007199254740992 - http://redis.io/commands/zadd
      def score _member
        @score ||= begin
          @member = _member
          member.created_at.to_i
        end
      end

    end
  end
end
