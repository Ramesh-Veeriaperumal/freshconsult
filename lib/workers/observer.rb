class Workers::Observer
  extend Resque::AroundPerform
  @queue = 'observer_worker'
  def self.perform args
    begin
      account = Account.current
      evaluate_on = account.tickets.find_by_id args[:ticket_id]
      doer = account.users.find_by_id args[:doer_id]

      if evaluate_on.present? && doer.present?
        current_events = args[:current_events].symbolize_keys
        Thread.current[:observer_doer_id] = doer.id

        account.observer_rules_from_cache.each do |vr|
          vr.check_events doer, evaluate_on, current_events
        end
        evaluate_on.save!
      else
        Rails.logger.debug "Observer Rules are not executed for account id :: #{Account.current.id}, Ticket id :: #{args[:ticket_id]}, Doer id :: #{args[:doer_id]}"
      end
    rescue Resque::DirtyExit
     Resque.enqueue(Workers::Observer, args)
    rescue Exception => e
      puts "something is wrong Observer : Account id:: #{Account.current.id}, Ticket id:: #{args[:ticket_id]}, #{e.message}"
      NewRelic::Agent.notice_error(e, {:custom_params => {:args => args }})
    ensure
      Thread.current[:observer_doer_id] = nil
    end
  end

end