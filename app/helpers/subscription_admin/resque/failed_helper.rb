module SubscriptionAdmin::Resque::FailedHelper

	def load_failed_array(start, queue_name, failed_in_given_queue, count)
		failed_count = Resque::Failure.count #in all queues			
		failed_in_all_qs =  Resque::Failure.all(start,range(start))	
		failed_in_all_qs.each do |qjob|			
			if qjob['queue'] == queue_name 
				if count >= 10
					break
				end	
				qjob['job_id'] = start		
				failed_in_given_queue << qjob
				count +=1
			end
			start +=1
		end 
		if count < 10 && start < failed_count
			load_failed_array(start, queue_name, failed_in_given_queue, count)
		else	
			return { :array => failed_in_given_queue, :job_parsed => start }
	  end
	end

	def url_path(*path_parts)
		[ path_prefix, path_parts ].join("/").squeeze('/')
	end 

	def path_prefix
		request.env['SCRIPT_NAME']
	end

	private
		def range(start)
			case start
				when 0..100
				 	to_ret = 20
				when 100..200
				  to_ret = 50
				when 200..300
					to_ret = 100
				else	
					to_ret = 500
			end
			to_ret
		end
 end