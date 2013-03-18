class Workers::Observer
# class Workers::Observer < Struct.new(:ticket_id, :user_id, :current_events)
  extend Resque::Plugins::Retry
  @queue = 'observer_worker'

  @retry_limit = 3
  @retry_delay = 60*2

  def self.perform ticket_id, user_id, current_events
  # def perform
    begin
      p User.current
      evaluate_on=nil
      ActiveRecord::Base.uncached do
        evaluate_on = Helpdesk::Ticket.find ticket_id
        p evaluate_on
        p evaluate_on.custom_field
      end

      account = evaluate_on.account
      account.make_current

      p "After Make Current"
      p Helpdesk::Ticket.find ticket_id
      doer = User.find user_id
      p current_events
      current_events.symbolize_keys!
      account.observer_rules.each do |vr|
        p vr.name
        vr.check_events doer, evaluate_on, current_events
      end
      
      p evaluate_on.changes
      p evaluate_on
      evaluate_on.save unless evaluate_on.changes.blank?
      p "Fecthing after saving it"
      p Helpdesk::Ticket.find ticket_id
    rescue Exception => e
      puts "something is wrong  : #{e.message}"
    rescue
      puts "something went wrong"
    end
  end

end