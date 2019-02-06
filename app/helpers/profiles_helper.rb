module ProfilesHelper
	def show_api_key?
		current_account.api_v2_enabled? && current_account.verified? && current_user.agent? && !current_account.launched?(:hide_api_key)
	end
end
