class Workers::Observer
  extend Resque::AroundPerform
  @queue = 'observer_worker'
  def self.perform args
    begin
      Rails.logger.debug "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$           RESQUE"
      
      p Account.current.tickets.find args[:ticket_id]
      ActiveRecord::Base.connection.reset!

      account = Account.current
#DJ
# class Workers::Observer < Struct.new(:args)
#   def perform
#     begin
#       p args[:current_events]      
#       account = Account.find args[:account_id]
      x = ActiveRecord::Base.connection.execute("SHOW STATUS LIKE 'Com_select'")
      x.each_hash{|r_h| p r_h.inspect }
      x = ActiveRecord::Base.connection.execute("SHOW STATUS LIKE 'Qcache_hits'")
      x.each_hash{|r_h| p r_h.inspect }
      
      evaluate_on = account.tickets.find args[:ticket_id]

      x = ActiveRecord::Base.connection.execute("SHOW STATUS LIKE 'Com_select'")
      x.each_hash{|r_h| p r_h.inspect }
      x = ActiveRecord::Base.connection.execute("SHOW STATUS LIKE 'Qcache_hits'")
      x.each_hash{|r_h| p r_h.inspect }

      doer = account.users.find args[:doer_id]
      current_events = args[:current_events].symbolize_keys

      p evaluate_on
      p evaluate_on.flexifield
      p evaluate_on.schema_less_ticket

      account.observer_rules_from_cache.each do |vr|
        vr.check_events doer, evaluate_on, current_events
      end

      p "Done"
      p evaluate_on.changes
      p evaluate_on.flexifield.changes
      p evaluate_on.schema_less_ticket.changes

      evaluate_on.save
      
    rescue Exception => e
      puts "something is wrong  : #{e.message}"
    rescue
      puts "something went wrong"
    end
  end

end