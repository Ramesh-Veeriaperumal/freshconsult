class Workers::Subscriber
  extend Resque::AroundPerform
  @queue = 'subscriber_worker'
  def self.perform args
    begin
      account = Account.current
      evaluate_on = account.send(args[:association].pluralize.to_sym).find args[:event_id]
      current_events = args[:current_events].symbolize_keys
      account.api_webhook_rules.each do |vr|
        is_a_match = vr.event_matches? current_events, evaluate_on
        vr.pass_through evaluate_on, nil, nil if is_a_match
      end
    rescue Resque::DirtyExit
      Resque.enqueue(Workers::Subscriber, args)
    rescue Exception => e
      puts "something is wrong  : #{e.message}"
    ensure
      Thread.current[:observer_doer_id] = nil
    end
  end
end