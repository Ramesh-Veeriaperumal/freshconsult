class Workers::Observer
  extend Resque::AroundPerform
  @queue = 'observer_worker'
  def self.perform args
    begin
      account = Account.current
      evaluate_on = account.tickets.find args[:ticket_id]
      doer = account.users.find args[:doer_id]
      current_events = args[:current_events].symbolize_keys

      account.observer_rules_from_cache.each do |vr|
        vr.check_events doer, evaluate_on, current_events
      end
      evaluate_on.save
      
    rescue Exception => e
      puts "something is wrong  : #{e.message}"
    rescue
      puts "something went wrong"
    end
  end

end