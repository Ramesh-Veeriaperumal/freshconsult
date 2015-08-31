### MULTILINGUAL SOLUTIONS - META READ HACK!!
class Community::HandleLanguageChange < BaseWorker

	sidekiq_options :queue => :solution_language_change, :retry => 0, :backtrace => true, :failures => :exhausted

	SOLUTION_ASSOCIATIONS = ["solution_categories", "solution_folders", "solution_articles"]

	def perform
		language_id = Language.for_current_account.id
		SOLUTION_ASSOCIATIONS.each do |solution_assoc|
			Account.current.send("#{solution_assoc}_without_association").find_in_batches(:batch_size => 100) do |objects|
				Account.current.send("#{solution_assoc}_without_association").where(
					:id => objects.map(&:id)).update_all(:language_id => language_id)
			end
		end
	end
end
