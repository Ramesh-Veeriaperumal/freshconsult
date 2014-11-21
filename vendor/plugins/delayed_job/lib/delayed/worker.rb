module Delayed
  class Worker
    SLEEP = 5

    cattr_accessor :logger
    self.logger = if defined?(Merb::Logger)
      Merb.logger
    elsif defined?(Rails.logger)
      Rails.logger
    end

    def initialize(model = ::Delayed::Job, options={})
      @quiet = options[:quiet]
      @model = model
      model.min_priority = options[:min_priority] if options.has_key?(:min_priority)
      model.max_priority = options[:max_priority] if options.has_key?(:max_priority)
    end

    def start
      say "*** Starting job worker #{@model.worker_name}"

      trap('TERM') { say 'Exiting...'; $exit = true }
      trap('INT')  { say 'Exiting...'; $exit = true }

      loop do
        result = nil

        realtime = Benchmark.realtime do
          result = @model.work_off
        end

        count = result.sum

        break if $exit

        if count.zero?
          sleep(SLEEP)
        else
          say "#{count} jobs processed at %.4f j/s, %d failed ..." % [count / realtime, result.last]
        end

        break if $exit
      end

    ensure
      @model.clear_locks!
    end

    def say(text)
      puts text unless @quiet
      logger.info text if logger
    end

  end
end
