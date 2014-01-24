
def log_file
    @log_file_path = "#{Rails.root}/log/rake.log"      
end 

def custom_logger(path)
    @custom_logger||=CustomLogger.new(path)
end

namespace :sla do
  desc 'Check for SLA violation and trigger emails..'
  task :escalate => :environment do
    begin
      puts "Check for SLA violation initialized at #{Time.zone.now}"
      path = log_file
      rake_logger = custom_logger(path)
    rescue Exception => e
      puts "Error occured #{e}"  
      FreshdeskErrorsMailer.deliver_error_email(nil,nil,e,{:subject => "Splunk logging Error for sla.rake",:recipients => "pradeep.t@freshdesk.com"})      
    end
    rake_logger.info "rake=SLA" unless rake_logger.nil?
    queue_name = "sla_worker"
    current_time = Time.now.utc
    if sla_should_run?(queue_name)
      accounts_queued = 0
      Sharding.execute_on_all_shards do
        Account.active_accounts.each do |account|        
          Resque.enqueue(Workers::Sla::AccountSLA, { :account_id => account.id})
          accounts_queued += 1
        end
      end
      begin
        redis_key = "stats:rake:sla:#{current_time.day}:#{current_time}"
        $stats_redis.set(redis_key, accounts_queued)
        $stats_redis.expire(redis_key, 144000)
      rescue => e
        puts "Error while recording SLA stats : #{e.message}"          
      end
    else
      begin
        redis_key = "stats:rake:sla:#{current_time.day}:#{current_time}"
        $stats_redis.set(redis_key, "skipped")
        $stats_redis.expire(redis_key, 144000)
      rescue => e
        puts "Error while recording SLA stats : #{e.message}"          
      end
    end
    puts "SLA rule check finished at #{Time.zone.now}."
  end
end

def sla_should_run?(queue_name)
  queue_length = Resque.redis.llen "queue:#{queue_name}"
  puts "#{queue_name} queue length is #{queue_length}"
  queue_length < 1 and !Rails.env.staging?
end

