class Workers::Observer
  extend Resque::Plugins::Retry
  @queue = 'observer_worker'

  @retry_limit = 3
  @retry_delay = 60*2

  def self.perform ticket_id, user_id, current_events
    begin
      evaluate_on = Helpdesk::Ticket.find ticket_id
      account = evaluate_on.account
      account.make_current
      current_user = User.find user_id
      current_events.symbolize_keys!

      account.observer_rules.each do |vr|
        vr.check_events current_user, evaluate_on, current_events
      end
      evaluate_on.save unless evaluate_on.changes.blank?
    rescue Exception => e
      puts "something is wrong  : #{e.message}"
    rescue
      puts "something went wrong"
    end
  end

end