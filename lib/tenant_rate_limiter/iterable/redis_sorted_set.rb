# frozen_string_literal: true

module TenantRateLimiter
  class Iterable::RedisSortedSet
    attr_accessor :options, :klass

    include TenantRateLimiter::Iterable::Constants
    include TenantRateLimiter::Iterable::RedisHelperMethods

    class << self
      include TenantRateLimiter::Iterable::Constants
      include TenantRateLimiter::Iterable::RedisHelperMethods

      def bootstrap
        init_connection_pool
        add_lua_scripts
        add_rate_limit_script
      end

      def init_connection_pool
        @redis_pool = ConnectionPool.new(timeout: 1, size: 5) { build_client }
      end

      private

        def add_lua_scripts
          redis_connection_pool do |conn|
            LUA_SCRIPTS.each_with_object(SHA) do |(name, lua), memo|
              memo[name] = conn.script(:load, lua)
            end
          end
        end

        def add_rate_limit_script
          SHA[:rate_limit] = $redis_others.script(:load, RATE_LIMIT_SCRIPT)
        end

        def build_client
          Redis.new(client_options(TENANT_REDIS_CONFIG))
        end

        def client_options(options)
          opts = options.dup
          opts.delete(:namespace) if opts[:namespace]

          if opts[:network_timeout]
            opts[:timeout] = opts[:network_timeout]
            opts.delete(:network_timeout)
          end

          opts[:driver] ||= 'ruby'
          opts[:reconnect_attempts] ||= 1
          opts
        end
    end

    def initialize(options)
      @redis_pool = self.class.init_connection_pool
      @klass = options[:worker_name].constantize
      @options = options
      @rate_limit = options[:rate_limit]
    end

    def iterate
      count = 0
      loop do
        jobs = fetch_jobs

        break if jobs.nil?

        jobs.each do |job|
          job_args = JSON.parse(job)
          begin
            yield(job_args)
          rescue StandardError => e
            Rails.logger.error("Error in #{@klass.name} :: #{e.message}")
            enqueue_retry(job_args)
            NewRelic::Agent.notice_error(e, custom_params: { description: "Error in #{@klass.name}", args: job_args })
          ensure
            count += 1
          end
        end
        break if jobs.length < REDIS_BATCH_SIZE
      end
      Rails.logger.debug("Processed #{count} jobs for #{@options[:tenant_id]} from RSS by TenantRateLimiter")
      exit_batch
    end

    def enqueue(params)
      redis_connection_pool do |conn|
        keys = [tenant_redis_key, accounts_set_key]
        args = [Account.current.id, params[@options[:event_timestamp_key]], JSON.dump(params), tenant_upper_threshold] # [Account id, Event timestamp, Job params json, Upper threshold]
        conn.evalsha(SHA[:enqueue], keys, args)
      end
    end

    private

      def fetch_jobs
        jobs_count = redis_connection_pool { |conn| jobs_count(conn, tenant_redis_key) }

        if jobs_count.positive?
          batch_size = jobs_count < REDIS_BATCH_SIZE ? jobs_count : REDIS_BATCH_SIZE

          jobs_count_to_process, first_batch_for_hour = $redis_others.evalsha(SHA[:rate_limit], [rate_limit_redis_key], [batch_size, @rate_limit])

          if jobs_count_to_process.zero?
            @rate_limit_exceeded = true
          else
            reset_metrics if first_batch_for_hour
            jobs, _no_more_jobs = redis_connection_pool do |conn| # TODO: Revisit no_more_jobs logic
              keys = [tenant_redis_key, accounts_set_key]
              args = [Time.now.to_f, jobs_count_to_process, Account.current.id] # [Current timestamp, number of jobs to be fetches, account_id]
              conn.evalsha(SHA[:dequeue], keys, args)
            end
          end
        end
        jobs
      end

      def enqueue_retry(args)
        retry_limit = @options[:retry]
        retry_count = args[:retry_count].to_i || 0
        retry_duration = RETRY_DURATION[retry_count]
        if retry_count < retry_limit
          retry_count += 1
          args[:retry_count] = retry_count
          result = redis_connection_pool do |conn|
            keys = [tenant_redis_key, accounts_set_key]
            args = [Account.current.id, retry_score(retry_duration), JSON.dump(args), tenant_upper_threshold]
            conn.evalsha(SHA[:enqueue], keys, args)
          end
          if result == TenantRateLimiter::Worker::TENANT_LIMIT_EXCEEDED
            @klass.notify_job_drop(args)
          else
            log_retry(retry_duration, retry_count)
          end
        else
          retry_exhausted
        end
      end

      def retry_score(duration)
        Time.now.to_f + duration
      end

      def tenant_redis_key
        @klass.tenant_key(@options[:tenant_id])
      end

      def accounts_set_key
        format(NAMESPACE_ACCOUNTS_SET_KEY, namespace: $namespace)
      end

      def exit_batch
        jobs_left = redis_connection_pool do |conn|
          conn.evalsha(SHA[:check_exit], [tenant_redis_key, accounts_set_key], [Account.current.id])
        end
        if jobs_left.zero?
          return -1
        elsif @rate_limit_exceeded
          rate_limit_exceeded_callback
          return [get_expiry(rate_limit_redis_key), 5].max
        else
          return 60
        end
      end

      def rate_limit_redis_key
        format(TENANT_RATE_LIMIT_KEY, type: @options[:worker_name], tenant_id: @options[:tenant_id])
      end

      # Jobs older than 24 hours will be dropped in the worker. Having 2 hours buffer data incase the limit is breached and later increased on demand
      def tenant_upper_threshold
        @klass.respond_to?(:tenant_upper_threshold) ? @klass.tenant_upper_threshold(@rate_limit) : Float::INFINITY
      end

      def retry_exhausted
        @klass.retry_exhausted(@options) if @klass.respond_to?(:retry_exhausted)
      end

      def log_retry(delay, retry_count)
        @klass.log_retry(delay, retry_count) if @klass.respond_to?(:log_retry)
      end

      def rate_limit_exceeded_callback
        @klass.rate_limit_exceeded_callback(@options) if @klass.respond_to?(:rate_limit_exceeded_callback)
      end

      def reset_metrics
        @klass.reset_metrics(@options) if @klass.respond_to?(:reset_metrics)
      end
  end
end
