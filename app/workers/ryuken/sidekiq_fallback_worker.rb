# When Sidekiq redis is down, jobs are pushed to Shoryuken.
# This is the worker for sidekiq jobs that falied to get enqueued to Redis.
#
class Ryuken::SidekiqFallbackWorker
  include Shoryuken::Worker
  
  shoryuken_options queue: ::SQS[:sidekiq_fallback_queue], body_parser: :json, auto_delete: true
                      
  def perform(sqs_msg, body)
    begin
      klass = body['class'].constantize
      job_args = body['args'].first
      if !job_args.nil?
        klass.new.perform(job_args)
      else 
        klass.new.perform
      end
      puts "Job Performed Successfully, Worker class is #{klass}, Job payload is #{job_args.inspect}"
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Shoryuken Job(sidekiq fallback) failed,
       #{e.message}, Worker class is #{klass}, Job payload is #{job_args.inspect}"}})
      puts e.inspect
    end
  end

end