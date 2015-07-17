module Gamification::GamificationUtil
	def gamification_feature?(account)
    # OPTIMIZE
    # features_included?(*) can be used instead of features?
		account.features_included?(:gamification) && account.features_included?(:gamification_enable)
	end
end