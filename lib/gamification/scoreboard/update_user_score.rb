module Gamification
  module Scoreboard
    class UpdateUserScore 
      extend Resque::AroundPerform
      @queue = "gamification_user_score"
      def self.perform(args)
        run(args)
      end

      class PremiumQueue <  UpdateUserScore
        @queue = "premium_gamification_user_score"
        def self.perform(args)
          run(args)
        end
      end

      def self.run(args)
        args.symbolize_keys!
        id, account_id = args[:id], args[:account_id]
        user = User.find_by_id_and_account_id(id, account_id)
        return if user.customer?
        total_score = user.support_scores.sum(:score)
        unless (user.agent.points.eql? total_score)
          user.agent.update_attribute(:points, total_score)
        end

        user.agent.clear_leaderboard_cache!(Account.current,user)
      end
    end
  end
end