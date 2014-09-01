module SubscriptionAdmin::Resque::HomeHelper
	def failed_queue_count(queue_name)
		count = 0
		jobs = Resque::Failure.all(0,Resque::Failure.count)
		jobs.each_with_index do |job,i|
		begin
			if (job['queue'] == queue_name)
				count+=1
			end
				rescue => e
			end
		end
		count
	end
end