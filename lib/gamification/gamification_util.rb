module Gamification::GamificationUtil
	def gamification_feature?(account)
		account.gamification_enabled? and account.gamification_enable_enabled?
	end
end