class Workers::Community::HandleLanguageChange
	extend Resque::AroundPerform

	@queue = 'language_change'

	class << self

		def perform(args)
			current_account = Account.current
			language_id = Language.find_by_code(current_account.language).id
			binding.pry
			["solution_categories", "solution_folders", "solution_articles"].each do |solution_assoc|
				current_account.send(solution_assoc).update_all(:language_id => language_id)
			end
		end
	end 
end
