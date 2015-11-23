module Admin::Sla::Reminder
  class Premium < Admin::Sla::Reminder::Base
    sidekiq_options :queue => :premium_sla_reminders, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end
