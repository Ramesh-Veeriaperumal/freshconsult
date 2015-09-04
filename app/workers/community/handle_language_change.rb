### MULTILINGUAL SOLUTIONS - META READ HACK!!
class Community::HandleLanguageChange < BaseWorker

	sidekiq_options :queue => :solution_language_change, :retry => 0, :backtrace => true, :failures => :exhausted

	SOLUTION_CLASSES = ["Solution::Category", "Solution::Folder", "Solution::Article"]

	def perform
		language_id = Language.for_current_account.id
		SOLUTION_CLASSES.each do |klass|
			klass.constantize.find_in_batches(:batch_size => 100, :conditions => {:account_id => Account.current.id}) do |objects|
				klass.constantize.where(
					:id => objects.map(&:id), :account_id => Account.current.id).update_all(:language_id => language_id)
			end
		end
	end
end
