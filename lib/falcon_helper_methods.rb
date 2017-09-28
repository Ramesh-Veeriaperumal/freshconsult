module FalconHelperMethods

  	def falcon_enabled?
	    current_account && current_account.launched?(:falcon) && current_user && current_user.is_falcon_pref?
	end
end