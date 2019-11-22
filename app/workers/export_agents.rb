class ExportAgents < BaseWorker

  sidekiq_options :queue => :export_agents, :retry => 0, :failures => :exhausted

  def perform args
    begin
      args.symbolize_keys!
      args[:export_job_id] = @jid
      Export::AgentDetail.new(args).perform
    ensure
      User.reset_current_user
      I18n.locale = I18n.default_locale
    end
  end

end