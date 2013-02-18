module CRM::TotangoModulesAndActions

	include CRM::TotangoOptions

	def totango_activity(key)
		MODULES_AND_ACTIONS[key]
	end
end