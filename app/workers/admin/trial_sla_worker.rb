module Admin
  class TrialSlaWorker < Admin::SlaWorker
    sidekiq_options :queue => :trial_sla, :retry => 0, :backtrace => true, :failures => :exhausted
  end
end