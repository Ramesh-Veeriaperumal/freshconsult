module Gamification
	module Scoreboard
		class UpdateUserScore < Resque::FreshdeskBase
			@queue = "gamificationQueue"

			def self.perform(args)
				args.symbolize_keys!
				id, account_id = args[:id], args[:account_id]
				user = User.find_by_id_and_account_id(id, account_id)
				total_score = user.support_scores.sum(:score)
      		unless (user.agent.points.eql? total_score)
        		user.agent.update_attribute(:points, total_score)
      		end
			end

		end
	end
end