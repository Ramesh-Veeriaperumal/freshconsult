module Gamification::GamificationUtil
	def gamification_feature?(account)
		account.features_included?(:gamification) && account.features_included?(:gamification_enable)
	end
end