class RunRakeTask < BaseWorker
  sidekiq_options :queue => :run_rake_task, :retry => 0, :failures => :exhausted

  def perform(args)
    if Rails.env.production?
      return
    else
      args.symbolize_keys!
      Rails.logger.info "Before running rake task : #{args.inspect}"
      if args[:additional_params].nil?
        %x(bundle exec rake #{args[:task]})
      else
        %x(bundle exec rake #{args[:task]}[#{args[:additional_params]}])
      end
      Rails.logger.info 'After running rake task'
    end
    rescue => exceptions
      Rails.logger.info "Exception while running rake task worker #{exception.inspect}"
  end
end
