module Admin::Sla::Reminder
  class Free < Admin::Sla::Reminder::Base
    sidekiq_options :queue => :free_sla_reminders, :retry => 0, :failures => :exhausted
  end
end