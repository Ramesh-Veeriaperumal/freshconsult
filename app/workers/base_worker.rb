require 'custom_logger'
require 'sidekiq/api'
class BaseWorker
  include Sidekiq::Worker
  include Redis::Semaphore

  protected

    def execute_on_db(db_name = 'run_on_slave')
      Sharding.safe_send(db_name.to_sym) do
        yield
      end
    end

    def empty_queue?(queue_name)
      queue_length = Sidekiq::Queue.new(queue_name).size
      logger.info "#{queue_name} queue length is #{queue_length}"
      queue_length.zero? # and !Rails.env.staging?
    end

    def log_file
      @log_file_path ||= "#{Rails.root}/log/sidekiq_custom.log"
    end

    def custom_logger
      @sla_logger ||= CustomLogger.new(log_file)
    rescue StandardError => e
      logger.info "Error occured while #{e}"
      FreshdeskErrorsMailer.error_email(nil, nil, e,
                                        subject: 'Splunk logging Error for sla',
                                        recipients: (Rails.env.production? ? Helpdesk::EMAIL[:production_dev_ops_email] : 'dev-ops@freshpo.com'))
    end

    def lock_and_run(key, expiry = nil)
      return if semaphore_exists?(key)

      set_semaphore(key, 1, expiry)
      yield
    ensure
      del_semaphore(key)
    end
end
