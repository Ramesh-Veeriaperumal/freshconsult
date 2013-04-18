class Workers::Observer
# class Workers::Observer < Struct.new(:ticket_id, :user_id, :current_events)
  extend Resque::AroundPerform
  @queue = 'observer_worker'

  def self.perform args
  # def perform
    begin
      account = Account.current
      evaluate_on = account.tickets.find args[:ticket_id]
      doer = account.users.find args[:current_user_id]
      current_events = args[:current_events].symbolize_keys

      p evaluate_on
      p evaluate_on.flexifield
      p evaluate_on.schema_less_ticket

      p evaluate_on.changes

      account.observer_rules.each do |vr|
        vr.check_events doer, evaluate_on, current_events
      end

      p "Done"
      p evaluate_on.changes
      p evaluate_on.flexifield.changes
      p evaluate_on.schema_less_ticket.changes

      evaluate_on.flexifield.save unless evaluate_on.flexifield.changes.blank?
      evaluate_on.save unless evaluate_on.changes.blank? 
      
    rescue Exception => e
      puts "something is wrong  : #{e.message}"
    rescue
      puts "something went wrong"
    end
  end

end