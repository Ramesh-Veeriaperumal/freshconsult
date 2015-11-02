module Gamification::GamificationUtil
	def gamification_feature?(account)
		account.features_included?(:gamification, :gamification_enable)
	end
end