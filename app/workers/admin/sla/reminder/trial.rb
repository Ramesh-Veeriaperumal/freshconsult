module Admin::Sla::Reminder
  class Trial < Admin::Sla::Reminder::Base
    sidekiq_options :queue => :trial_sla_reminders, :retry => 0, :failures => :exhausted
  end
end