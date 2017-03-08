module Admin::Sla::Escalation
  class Premium < Admin::Sla::Escalation::Base
    sidekiq_options :queue => :premium_sla, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end