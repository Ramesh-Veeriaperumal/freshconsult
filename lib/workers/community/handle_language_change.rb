### MULTILINGUAL SOLUTIONS - META READ HACK!!
class Workers::Community::HandleLanguageChange
	extend Resque::AroundPerform

	@queue = 'language_change'

	class << self

		def perform(args)
			current_account = Account.current
			language_id = Language.for_current_account.id
			["solution_categories", "solution_folders", "solution_articles"].each do |solution_assoc|
				current_account.send("#{solution_assoc}_without_association").update_all(
					:language_id => language_id)
			end
		end
	end 
end
