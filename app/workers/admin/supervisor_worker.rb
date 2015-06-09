module Admin
  class SupervisorWorker < BaseWorker

    sidekiq_options :queue => :supervisor, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform
      account = Account.current
      supervisor_rules = execute_on_db { account.supervisor_rules }
      return unless supervisor_rules.count > 0 
      start_time = Time.now.utc
      supervisor_rules.each do |rule|
        begin
          rule_start_time = Time.now.utc
          conditions = execute_on_db { rule.filter_query }
          next if conditions.empty?
          negate_conditions = [""]
          negate_conditions = execute_on_db { rule.negation_query } if $redis_others.get("SUPERVISOR_NEGATION")
          logger.info "rule name::::::::::#{rule.name}"
          logger.info "conditions::::::: #{conditions.inspect}"
          logger.info "negate_conditions::::#{negate_conditions.inspect}"
          joins = execute_on_db { rule.get_joins(["#{conditions[0]} #{negate_conditions[0]}"]) }
          tickets = execute_on_db { account.tickets.where(negate_conditions).where(conditions).updated_in(1.month.ago).visible.joins(joins).select("helpdesk_tickets.*") }
          tickets.each do |ticket|
            begin
              rule.trigger_actions ticket
              ticket.save_ticket!
            rescue Exception => e
              logger.info "::::::::::::::::::::error:::::::::::::#{rule.inspect}"
              logger.info e
              logger.info ticket.inspect
              NewRelic::Agent.notice_error(e,{:description => "Error while executing supervisor rule for a tkt :: #{ticket.id} :: account :: #{account.id}" })
              next
            end
          end
          rule_end_time = Time.now.utc
          rule_total_time = (rule_end_time - rule_start_time )
          log_format=logging_format(account,tickets.length,rule,rule_total_time)
          custom_logger.info "#{log_format}" unless custom_logger.nil?  

        rescue Exception => e
          logger.info e.backtrace.join("\n")
          logger.info "something is wrong: #{e.message}"
          NewRelic::Agent.notice_error(e)
        rescue
          logger.info "something went wrong"
        end
      end
      end_time = Time.now.utc
      if((end_time - start_time) > 250)
        total_time = Time.at(Time.now.utc - start_time).gmtime.strftime('%R:%S')
        logger.info "Time total time it took to execute the supervisor rules for, #{account.id}, #{account.full_domain}, #{total_time}"
      end
    ensure
      Account.reset_current_account
    end

    private

      def log_file
        @log_file_path ||= "#{Rails.root}/log/supervisor.log"      
      end 
      
      def logging_format(account,tickets_count,rule,rule_total_time)
        "account_id=#{account.id}, account_name=#{account.name}, fullname=#{account.full_domain}, tickets=#{tickets_count}, time_taken=#{rule_total_time}, rule=#{rule.name}, host_name=#{Socket.gethostname} "      
      end 
  end
end