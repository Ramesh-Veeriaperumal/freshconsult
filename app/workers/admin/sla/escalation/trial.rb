module Admin::Sla::Escalation
  class Trial < Admin::Sla::Escalation::Base
    sidekiq_options :queue => :trial_sla, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end