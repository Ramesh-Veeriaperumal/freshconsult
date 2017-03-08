module Admin::Sla::Escalation
  class Trial < Admin::Sla::Escalation::Base
    sidekiq_options :queue => :trial_sla, :retry => 1, :backtrace => true, :failures => :exhausted
  end
end