class Workers::Observer
# class Workers::Observer < Struct.new(:ticket_id, :user_id, :current_events)
  extend Resque::AroundPerform
  @queue = 'observer_worker'

  def self.perform args
  # def perform
    begin
      p Account.current
      p User.current
      p args

      account = Account.current
      evaluate_on = nil
      ActiveRecord::Base.uncached do
        evaluate_on = account.tickets.find args[:ticket_id]
        p evaluate_on
        p evaluate_on.custom_fields
        p evaluate_on.flexifield
      end
      doer = account.users.find args[:current_user_id]
      current_events = args[:current_events].symbolize_keys
      account.observer_rules.each do |vr|
        vr.check_events doer, evaluate_on, current_events
      end
      p evaluate_on.changes
      p evaluate_on
      evaluate_on.save unless evaluate_on.changes.blank?
    rescue Exception => e
      puts "something is wrong  : #{e.message}"
    rescue
      puts "something went wrong"
    end
  end

end