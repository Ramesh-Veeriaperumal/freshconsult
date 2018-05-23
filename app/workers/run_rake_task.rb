class RunRakeTask < BaseWorker

  sidekiq_options :queue => :run_rake_task, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform args
    begin
      args.symbolize_keys!
      Rails.logger.debug "Before running rake task"
      args[:additional_params].nil? ? %x(bundle exec rake #{args[:task]}) : %x(bundle exec rake #{args[:task]}[#{args[:additional_params]}])
      Rails.logger.debug "After running rake task"
    rescue => e
      Rails.logger.debug "exception #{e}"
    end
  end

end
