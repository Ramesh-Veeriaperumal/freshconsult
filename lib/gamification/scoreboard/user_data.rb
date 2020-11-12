module Gamification
  module Scoreboard
    class UserData 

      def initialize(args)
        args.symbolize_keys!
        id, account_id = args[:id], args[:account_id]
        @user = ::User.find_by_id_and_account_id(id,account_id)
      end

      def update_score
        return if @user.customer?
        total_score = nil
        Sharding.run_on_slave do
          total_score = @user.support_scores.sum(:score)
        end
        unless (@user.agent.points.eql? total_score)
          agent = @user.agent
          agent.gamification_update = true
          agent.update_attribute(:points, total_score)
        end
      end
    end
  end
end