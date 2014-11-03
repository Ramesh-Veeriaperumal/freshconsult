class Workers::Supervisor
  extend Resque::AroundPerform
  

  @queue = 'supervisor_worker'
  
  class TrialAccounts
    extend Resque::AroundPerform
    @queue = 'trial_supervisor_worker'

    def self.perform(args)
     Workers::Supervisor.run
    end
  end

  class FreeAccounts
    extend Resque::AroundPerform
    @queue = 'free_supervisor_worker'

    def self.perform(args)
     Workers::Supervisor.run
    end
  end

  class PremiumSupervisor
    extend Resque::AroundPerform
    @queue = 'premium_supervisor_worker'

    def self.perform(args)
     Workers::Supervisor.run
    end
  end

  def self.perform(args)
    run
  end

  def self.log_file
    @log_file_path = "#{Rails.root}/log/supervisor.log"      
  end 
  
  def self.logging_format(account,tickets_count,rule,rule_total_time)
    @log_file_format = "account_id=#{account.id}, account_name=#{account.name}, fullname=#{account.full_domain}, tickets=#{tickets_count}, time_taken=#{rule_total_time}, rule=#{rule.name}, host_name=#{Socket.gethostname} "      
  end 
  
  def custom_logger(path)
    @custom_logger||=CustomLogger.new(path)
  end

  def self.run
    # total_tickets = 0
    begin
      path = log_file
      supervisor_logger = custom_logger(path)
    rescue Exception => e
      puts "Error occured while #{e}"
      FreshdeskErrorsMailer.error_email(nil,nil,e,{:subject => "Splunk logging Error for supervisor",:recipients => "pradeep.t@freshdesk.com"})  
    end
    account = Account.current
    return unless account.supervisor_rules.count > 0 
    start_time = Time.now.utc
    account.supervisor_rules.each do |rule|
      begin
        rule_start_time = Time.now.utc
        puts "rule name before checking the condition ::::::::::#{rule.name}"
        conditions = rule.filter_query
        next if conditions.empty?
        negate_conditions = [""]
        negate_conditions = rule.negation_query if $redis_others.get("SUPERVISOR_NEGATION")
        puts "rule name::::::::::#{rule.name}"
        puts "conditions::::::: #{conditions.inspect}"
        puts "negate_conditions::::#{negate_conditions.inspect}"
        joins  = rule.get_joins(["#{conditions[0]} #{negate_conditions[0]}"])
        tickets = Sharding.run_on_slave { account.tickets.where(negate_conditions).where(conditions).updated_in(1.month.ago).visible.find(:all, :joins => joins, :select => "helpdesk_tickets.*") }
        tickets.each do |ticket|
          begin
            rule.trigger_actions ticket
            ticket.save_ticket!
          rescue Exception => e
            Rails.logger.info "::::::::::::::::::::error:::::::::::::#{rule.inspect}"
            Rails.logger.debug e
            Rails.logger.debug ticket.inspect
            NewRelic::Agent.notice_error(e)
            next
          end
        end
        # total_tickets += tickets.length
        rule_end_time = Time.now.utc
        rule_total_time = (rule_end_time - rule_start_time )
        log_format=logging_format(account,tickets.length,rule,rule_total_time)
        supervisor_logger.info "#{log_format}" unless supervisor_logger.nil?  
      rescue Exception => e
        puts e.backtrace.join("\n")
        puts "something is wrong: #{e.message}"
      rescue
        puts "something went wrong" 
      end
    end    
    end_time = Time.now.utc
    if((end_time - start_time) > 250)
      total_time = Time.at(Time.now.utc - start_time).gmtime.strftime('%R:%S')
      puts "Time total time it took to execute the supervisor rules for, #{account.id}, #{account.full_domain}, #{total_time}"
    end
  end

end  