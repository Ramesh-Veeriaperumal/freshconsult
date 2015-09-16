module Solution::DraftContext
	include Redis::RedisKeys
	
	def save_context
		@drafts_context = current_portal.id
		newrelic_begin_rescue do
			$redis_others.set(solutions_draft_key, params[:portal].to_i) if portal_check
			get_context
			set_expiry
		end
	end

	private
		def portal_check
			return false unless params[:portal].present?
			validate_portal
		end

		def set_expiry
			$redis_others.expire(solutions_draft_key, 1.days.to_i)
		end

		def validate_portal
			#portal_id will be set to '0' for "all categories" selection
			current_account.portals.map(&:id).include?(params[:portal].to_i) || (params[:portal].to_i == 0)
		end

		def get_context
			@drafts_context = $redis_others.get(solutions_draft_key).to_i || current_portal.id
			@drafts_context_portal = current_account.portals.find(@drafts_context)
		end

		def solutions_draft_key
			SOLUTION_DRAFTS_SCOPE % { :account_id => current_account.id, :user_id => current_user.id }
		end

end