module Admin::Sla::Escalation
  class Free < Admin::Sla::Escalation::Base
    sidekiq_options :queue => :free_sla, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end