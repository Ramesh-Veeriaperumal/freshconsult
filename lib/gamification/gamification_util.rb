module Gamification::GamificationUtil
	def gamification_feature?(account)
		account.features?(:gamification) && account.features?(:gamification_enable)
	end
end