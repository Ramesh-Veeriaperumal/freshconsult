module Admin::Sla::Reminder
  class Trial < Admin::Sla::Reminder::Base
    sidekiq_options :queue => :trial_sla_reminders, :retry => 1, :backtrace => true, :failures => :exhausted
  end
end