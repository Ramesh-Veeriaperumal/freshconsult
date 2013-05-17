class Workers::Supervisor
  extend Resque::AroundPerform
  

  @queue = 'supervisor_worker'
  
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

 

  def self.run
    account = Account.current
    SeamlessDatabasePool.use_persistent_read_connection do
      start_time = Time.now.utc
    account.supervisor_rules.each do |rule|
      begin
        conditions = rule.filter_query
        next if conditions.empty?
        negate_conditions = rule.negation_query
        
        puts "rule name::::::::::#{rule.name}"
        puts "conditions::::::: #{conditions.inspect}"
        puts "negate_conditions::::#{negate_conditions.inspect}"
        joins  = rule.get_joins(["#{conditions[0]} #{negate_conditions[0]}"])
        account.tickets.scoped(:conditions => negate_conditions).scoped(:conditions => conditions).updated_in(1.month.ago).visible.find_in_batches(:joins => joins,:readonly => false, :batch_size => 300) do |tickets|
          tickets.each do |ticket|
            rule.trigger_actions ticket
            ticket.save!
          end
        end

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
end