class MigrationWorker < BaseWorker

  sidekiq_options :queue => :migration,
                  :retry => false,
                  :backtrace => true,
                  :failures => :exhausted

  def perform args
    args = args.deep_symbolize_keys
    klass = args[:klass]
    options = args[:options]
    Thread.current[:migration_klass] = klass
    klass.constantize.new(options).perform
  end
end
