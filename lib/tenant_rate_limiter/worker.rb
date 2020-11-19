# frozen_string_literal: true

module TenantRateLimiter
  module Worker
    DEFAULT_TENANT_CLASS = 'Account'.freeze
    ENQUEUE_TENANT_JOB = 1
    TENANT_LIMIT_EXCEEDED = 2

    def self.included(base)
      base.extend(ClassMethods)
      base.include(InstanceMethods)
      base.include(TenantRateLimiter::Errors)
      base.class_attribute :options
    end

    module ClassMethods
      def sidekiq_options(options = {})
        init_options(options)
        define_klass(self.name, options)
      end

      def perform_async(args)
        check_and_enqueue_atomically(args)
      end

      private

        def init_options(options)
          options[:retry] ||= 0
          options[:batch_size] ||= 50
          self.options = options
        end

        def define_klass(klass_name, options)
          klass = Class.new(BaseWorker) do
            include TenantRateLimiter::Worker::InstanceMethods

            sidekiq_options options

            define_method :perform do |args|
              args.symbolize_keys!
              bulk_process_with_rate_limit(args) do |job_args|
                klass_name.constantize.new.perform(job_args)
              end
            end
          end

          klass_prefix = klass_name.constantize.respond_to?(:tenant_class) ? klass_name.constantize.tenant_class : DEFAULT_TENANT_CLASS
          worker_name = "#{klass_prefix}#{self.name}"
          @sidekiq_klass_name = "TenantRateLimiter::#{worker_name}"
          TenantRateLimiter.const_set(worker_name, klass)
        end

        # Checks Account set inside namespace and decide to enqueue sidekiq job or just add the event to account jobs sorted set
        def check_and_enqueue_atomically(args)
          options = iterable_options(args)
          result = iterable(options).enqueue(args)
          Rails.logger.debug "TenantRateLimiter :: Enqueue result :: #{result}"
          if result == ENQUEUE_TENANT_JOB
            @sidekiq_klass_name.constantize.perform_async(args.merge(options))
          elsif result == TENANT_LIMIT_EXCEEDED
            notify_job_drop(args)
          end
        end

        def notify_job_drop
          # TODO: Generic implementaion
          # Has been overridden in end worker
        end
    end

    module InstanceMethods
      ITERABLE_MAPPING = {
        'redis_sorted_set': 'TenantRateLimiter::Iterable::RedisSortedSet'
      }.with_indifferent_access.freeze

      def bulk_process_with_rate_limit(options)
        iterable_obj = iterable(options)
        res = iterable_obj.iterate do |job_args|
          yield(job_args)
        end
        Rails.logger.debug "TenantWorker :: Bulk process Result : #{res}"
        current_tenant(options[:tenant_id], options[:worker_name])
        self.class.perform_in(res, options) if res.positive?
      end

      def current_tenant(tenant_id, worker_name)
        tenant_object(tenant_id, worker_name).make_current
      end

      def tenant_object(tenant_id, worker_name)
        # Either tenant_object or tenant_class has to be initialized in end worker class
        # For Freshdesk it is kept as Account by default. Will be removed if extracted out
        worker_class = worker_name.constantize
        tenant_class = worker_class.respond_to?(:tenant_class) ? worker_class.tenant_class : DEFAULT_TENANT_CLASS
        klass = (tenant_class || DEFAULT_TENANT_CLASS).constantize
        klass.find(tenant_id)
      rescue ActiveRecord::RecordNotFound => e
        NewRelic::Agent.notice_error(e)
        Rails.logger.debug "TenantRateLimiter Error :: #{klass} with id #{tenant_id} not found"
        raise TenantRateLimiter::Errors::InvalidTenant
      rescue Account::RecordNotFound => e
        NewRelic::Agent.notice_error(e)
        Rails.logger.debug "Account with id #{tenant_id} not found"
        raise TenantRateLimiter::Errors::InvalidTenant
      end

      def iterable_class(type = 'redis_sorted_set')
        klass = ITERABLE_MAPPING[type]
        raise TenantRateLimiter::Errors::InvalidIterableType if klass.nil?

        klass
      end

      # Currently implementing only for Redis sorted set. Could be extended to AR
      def iterable(options)
        iterable_class(options[:type]).constantize.new(options)
      end
    end
  end
end
