require 'active_record_shards'

module Delayed

  class DeserializationError < StandardError
  end

  # A job object that is persisted to the database.
  # Contains the work object as a YAML field.
  class Job < ActiveRecord::Base
    
    self.table_name =  :delayed_jobs
    self.primary_key = :id
    not_sharded

    before_save { self.run_at ||= self.class.db_time_now }
    MAX_ATTEMPTS = 25
    MAX_PAYLOAD_SIZE = 32768 #32KB
    MAX_RUN_TIME = 4.hours
    JOB_QUEUES = ["Premium" , "Free", "Trial" , "Active"]
    PUSH_QUEUE = ["Free", "Trial", "Premium", "Active"]

    # By default failed jobs are destroyed after too many attempts.
    # If you want to keep them around (perhaps to inspect the reason
    # for the failure), set this to false.
    cattr_accessor :destroy_failed_jobs
    self.destroy_failed_jobs = true

    # Every worker has a unique name which by default is the pid of the process.
    # There are some advantages to overriding this with something which survives worker retarts:
    # Workers can safely resume working on tasks which are locked by themselves. The worker will assume that it crashed before.
    cattr_accessor :worker_name
    self.worker_name = "host:#{Socket.gethostname} pid:#{Process.pid}" rescue "pid:#{Process.pid}"

    NextTaskSQL         = '(run_at <= ? AND (locked_at IS NULL OR locked_at < ?) OR (locked_by = ?)) AND failed_at IS NULL'
    NextTaskOrder       = 'priority DESC, run_at ASC'

    ParseObjectFromYaml = /\!ruby\/\w+\:([^\s]+)/

    cattr_accessor :min_priority, :max_priority
    self.min_priority = nil
    self.max_priority = nil
    
    JobPodConfig = YAML.load_file(File.join('config', 'pod_info.yml'))

    default_scope ->{ where("pod_info = ?", "#{JobPodConfig['CURRENT_POD']}")}

    # When a worker is exiting, make sure we don't have any locked jobs.
    def self.clear_locks!
      where(['locked_by = ?', worker_name]).update_all('locked_by = null, locked_at = null')
    end

    # When a worker is exiting, make sure we don't run the same job again
    def update_run_at_for_syck_errors
      update_attribute(:run_at, Delayed::Job.db_time_now + 1.year)
    end

    def act_as_directory
    end

    def failed?
      failed_at
    end
    alias_method :failed, :failed?

    def payload_object
      @payload_object ||= deserialize(self['handler'])
    end

    def name
      @name ||= begin
        payload = payload_object
        if payload.respond_to?(:display_name)
          payload.display_name
        else
          payload.class.name
        end
      end
    end

    def payload_object=(object)
      self['handler'] = YAML.dump(object)
    end

    # Reschedule the job in the future (when a job fails).
    # Uses an exponential scale depending on the number of failed attempts.
    def reschedule(message, backtrace = [], time = nil)
      if self.attempts < MAX_ATTEMPTS
        reschedule_timespan = (attempts ** 4) + 5
        reschedule_timespan = 4.hours if (reschedule_timespan > 4.hours) 
        time ||= Job.db_time_now + reschedule_timespan

        self.attempts    += 1
        self.run_at       = time
        self.last_error   = message + "\n" + backtrace.join("\n")
        self.unlock
        save!
      else
        Rails.logger.info "* [JOB] PERMANENTLY removing #{self.name} because of #{attempts} consequetive failures."
        destroy_failed_jobs ? destroy : update_attribute(:failed_at, Delayed::Job.db_time_now)
      end
    end

    def reschedule_without_lock(message, backtrace = [], time = nil, account_id=-1)
      if self.attempts < MAX_ATTEMPTS
        reschedule_timespan = (attempts ** 4) + 5
        reschedule_timespan = 4.hours if (reschedule_timespan > 4.hours) 
        time ||= Job.db_time_now + reschedule_timespan

        self.attempts    += 1
        self.run_at       = time
        self.last_error   = message + "\n" + backtrace.join("\n")
        save!
      else
        Rails.logger.info "* [JOB] PERMANENTLY removing #{self.name} [ID] #{self.id} because of #{attempts} consequetive failures. account_id:#{account_id} Destroy flag: #{destroy_failed_jobs} Handler: #{self.handler}"
        destroy_failed_jobs ? destroy : update_attribute(:failed_at, Delayed::Job.db_time_now)
      end
    end

    def run_without_lock (account_id=-1)
      max_run_time = MAX_RUN_TIME
      begin
        runtime =  Benchmark.realtime do
          Timeout::timeout(max_run_time) do
            invoke_job
          end
          destroy
        end
        # TODO: warn if runtime > max_run_time ?
        Rails.logger.info "* [JOB] #{name} [ID] #{self.id} completed after %.4f. account_id:#{account_id} " % runtime
        return true  # did work
      rescue Timeout::Error => e
        NewRelic::Agent.notice_error(e, {:description => "Maximum run time - #{max_run_time} reached for [JOB] #{self.id}"})
        reschedule_without_lock e.message, e.backtrace, nil, account_id
        log_exception(e, account_id)
        raise e
      rescue Exception => e
        reschedule_without_lock e.message, e.backtrace, nil, account_id
        log_exception(e, account_id)
        raise e  # work failed
      end
    end

    # Try to run one job. Returns true/false (work done/work failed) or nil if job can't be locked.
    def run_with_lock(max_run_time, worker_name)
      Rails.logger.tagged SecureRandom.hex(20) do
        Rails.logger.info "* [JOB] aquiring lock on #{name} -- #{worker_name} with MAX_RUN_TIME = #{max_run_time}"
        unless lock_exclusively!(max_run_time, worker_name)
          # We did not get the lock, some other worker process must have
          Rails.logger.warn "* [JOB] failed to aquire exclusive lock for #{name}"
          return nil # no work done
        end
        Rails.logger.info "* [JOB] aquired lock on #{name} -worker_name- #{worker_name}  -payload- #{payload_object}"
        begin
          runtime =  Benchmark.realtime do
            Timeout::timeout(max_run_time) do
              invoke_job
            end
            destroy
          end
          # TODO: warn if runtime > max_run_time ?
          Rails.logger.info "* [JOB] #{name} [ID] #{self.id} completed after %.4f -- by worker - #{worker_name}" % runtime
          return true  # did work
        rescue Timeout::Error => e
          NewRelic::Agent.notice_error(e, {:description => "Maximum run time - #{max_run_time} reached for [JOB] #{name} -- #{worker_name}"})
          reschedule e.message, e.backtrace
          log_exception(e)
          return false
        rescue Exception => e
          reschedule e.message, e.backtrace
          log_exception(e)
          return false  # work failed
        end
      end
    end

    # Add a job to the queue
    def self.enqueue(*args, &block)
      object = block_given? ? EvaledJob.new(&block) : args.shift

      unless object.respond_to?(:perform) || block_given?
        raise ArgumentError, 'Cannot enqueue items which do not respond to perform'
      end

      unless YAML.dump(object).size < MAX_PAYLOAD_SIZE
        Rails.logger.debug "DEBUG ::: MaxPayloadSizeExceedError :: Payload size: #{YAML.dump(object).size}"
      end
    
      priority = args.first || 0
      run_at   = args[1]

      pod_info = JobPodConfig['CURRENT_POD']
      smtp_mailboxes = []

      if Account.current

        account_id = Account.current.id

        if Account.current.launched?(:disable_emails)
          Rails.logger.info "Outgoings emails are stopped for account #{account_id} due to :disable_emails feature."
          return
        end

        shard = ShardMapping.lookup_with_account_id(account_id)
        pod_info = shard.pod_info if (shard and !shard.pod_info.blank?)

        smtp_mailboxes = Account.current.smtp_mailboxes

        Rails.logger.info "Adding job to POD: #{pod_info} for account: #{Account.current} with id #{account_id}."

        job_queue = "spam" if Account.current.spam_email?
        job_queue ||= "premium" if Account.current.premium_email?
        job_queue ||= Account.current.subscription.state
        job_queue.capitalize!

        #queue everything else into the delayed_jobs table
        job_queue = "Delayed" if ( !JOB_QUEUES.include?(job_queue) || Rails.env.development? || Rails.env.test? )
      end

      job_params = { :payload_object => object, 
                     :priority => priority.to_i, 
                     :run_at => run_at, 
                     :pod_info => pod_info,
                     :account_id => account_id,
                     :sidekiq_job_info => worker_name

                   }

      perform_type = run_at.present? ? ["perform_at", run_at] : ["perform_async"]

      begin
        #Note: Right now if any smtp_mailbox for the current account is active ,it is added to
        #mailbox::Job queue. In Future we should check each individual smtp_mailbox based on the ticket and change the queue. 
        if smtp_mailboxes.any?{|smtp_mailbox| smtp_mailbox.enabled?}
          job = Mailbox::Job.create(job_params)
          worker_id = DelayedJobs::MailboxJob.safe_send(*perform_type, 
            {:job_id => job.id, :account_id => account_id}) if job && job.id
        else
          job = Object.const_get("#{job_queue}::Job").create(job_params)
          worker_id = Object.const_get("DelayedJobs::#{job_queue}AccountJob").safe_send(*perform_type, 
            {:job_id => job.id, 
             :account_id => account_id}) if job && job.id && PUSH_QUEUE.include?(job_queue)
        end
        if job
          #job.update_attribute(:sidekiq_job_info, "#{worker_id}:#{worker_name}")
          Rails.logger.info "Job #{job.id} created and pushed to the sidekiq queue #{job_queue} with id #{worker_id}" 
        end
        job
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    end

    # Find a few candidate jobs to run (in case some immediately get locked by others).
    # Return in random order prevent everyone trying to do same head job at once.
    def self.find_available(limit = 5, max_run_time = self::MAX_RUN_TIME)

      time_now = db_time_now

      sql = NextTaskSQL.dup

      conditions = [time_now, time_now - max_run_time, worker_name]

      if self.min_priority
        sql << ' AND (priority >= ?)'
        conditions << min_priority
      end

      if self.max_priority
        sql << ' AND (priority <= ?)'
        conditions << max_priority
      end

      conditions.unshift(sql)

      records = ActiveRecord::Base.silence do
        where(conditions).limit(limit)
      end

      records.sort_by { rand() }
    end

    # Run the next job we can get an exclusive lock on.
    # If no jobs are left we return nil
    def self.reserve_and_run_one_job(max_run_time = self::MAX_RUN_TIME)
      # We get up to 5 jobs from the db. In case we cannot get exclusive access to a job we try the next.
      # this leads to a more even distribution of jobs across the worker processes
      find_available(5, max_run_time).each do |job|
        t = job.run_with_lock(max_run_time, worker_name)
        return t unless t == nil  # return if we did work (good or bad)
      end

      nil # we didn't do any work, all 5 were not lockable
    end

    # Lock this job for this worker.
    # Returns true if we have the lock, false otherwise.
    def lock_exclusively!(max_run_time, worker = worker_name)
      now = self.class.db_time_now
      affected_rows = if locked_by != worker
        # We don't own this job so we will update the locked_by name and the locked_at
        self.class.where(['id = ? and (locked_at is null or locked_at < ?)', id, (now - max_run_time.to_i)]).update_all(['locked_at = ?, locked_by = ?', now, worker])
      else
        # We already own this job, this may happen if the job queue crashes.
        # Simply resume and update the locked_at
        self.class.where(['id = ? and locked_by = ?', id, worker]).update_all(['locked_at = ?', now])
      end
      if affected_rows == 1
        self.locked_at    = now
        self.locked_by    = worker
        return true
      else
        return false
      end
    end

    # Unlock this job (note: not saved to DB)
    def unlock
      self.locked_at    = nil
      self.locked_by    = nil
    end

    # This is a good hook if you need to report job processing errors in additional or different ways
    def log_exception(error, account_id=-1)
      Rails.logger.error "* [JOB] #{name} [ID] #{self.id} failed with #{error.class.name}: #{error.message} - #{attempts} failed attempts. account_id:#{account_id}"
      Rails.logger.error(error)
    end

    # Do num jobs and return stats on success/failure.
    # Exit early if interrupted.
    def self.work_off(num = 100)
      success, failure = 0, 0

      num.times do
        case self.reserve_and_run_one_job
        when true
            success += 1
        when false
            failure += 1
        else
          break  # leave if no work could be done
        end
        break if $exit # leave if we're exiting
      end

      return [success, failure]
    end

    # Moved into its own method so that new_relic can trace it.
    def invoke_job
      begin
        Thread.current[:attempts] = self.attempts
        Account.reset_current_account
        payload_object.perform
        Thread.current[:attempts] = nil
      rescue => e
        if (e.to_s.downcase.include?("line length exceeded"))
          handle_line_length_exceeded_emails
        else
          raise e
        end
      end
    end

    # utility to handle line length exceeded emails
    def handle_line_length_exceeded_emails
      begin
        Thread.current[:line_length_exceeded] = true
        payload_object.perform
        Thread.current[:attempts] = nil
        Rails.logger.info "Line Length Exceeded. Mail Parts are converted to Base64"
      rescue => e
        raise e
      ensure
        Thread.current[:line_length_exceeded] = nil
      end
    end

  private

    def deserialize(source)
      handler = YAML.load(source) rescue nil

      unless handler.respond_to?(:perform)
        if handler.nil? && source =~ ParseObjectFromYaml
          handler_class = $1
        end
        attempt_to_load(handler_class || handler.class)
        handler = YAML.load(source)
      end

      return handler if handler.respond_to?(:perform)

      raise DeserializationError,
        'Job failed to load: Unknown handler. Try to manually require the appropiate file.'
    rescue TypeError, LoadError, NameError => e
      update_run_at_for_syck_errors
      notification_topic = SNS["dev_ops_notification_topic"]
      # DevNotification.publish(notification_topic,"Delayed Job failed to load with job id #{self.id}", "Syck error unable to deserialize")
      raise DeserializationError,
        "Job failed to load: #{e.message}. Try to manually require the required file."
    end

    # Constantize the object so that ActiveSupport can attempt
    # its auto loading magic. Will raise LoadError if not successful.
    def attempt_to_load(klass)
       klass.constantize
    end

    # Get the current time (GMT or local depending on DB)
    # Note: This does not ping the DB to get the time, so all your clients
    # must have syncronized clocks.
    def self.db_time_now
      (ActiveRecord::Base.default_timezone == :utc) ? Time.now.utc : Time.zone.now
    end

  protected

    # TODO-RAILS3 moved as lmdb
    # def before_save
    #   self.run_at ||= self.class.db_time_now
    # end

  end

  class EvaledJob
    def initialize
      @job = yield
    end

    def perform
      eval(@job)
    end
  end
end
