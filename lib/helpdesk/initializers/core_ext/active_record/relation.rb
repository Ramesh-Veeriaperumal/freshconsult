# Additional custom methods under core classes
# [Core class] ActiveRecord::Relation
#
module ActiveRecord
  class Relation
    # Can be used with only hash params
    # Since update_all will be attr=val operations, we can pass as hash.
    # Usages:
    # update_all_with_publish(updates) - Will frame converse conditions
    # update_all_with_publish(updates, {}) - Set conditions to {} if converse conditions aren't required.
    #
    def update_all_with_publish(updates_hash, conditions = nil, options = {})
      count             = 0
      batch_size        = options.delete(:batch_size) || 500
      filter_conditions = conditions || frame_converse_conditions(updates_hash)
      rate_limit        = options.delete(:rate_limit) || {}

      Sharding.run_on_slave do
        loop do
          record_ids = where(filter_conditions).limit(batch_size).pluck(:id)

          if record_ids.present?
            records = where(id: record_ids)
            records.update_all_without_batching(updates_hash, options)
            count += record_ids.count
          end

          # Stop this batch if the current batch size wasn't big enough or
          #   if the rate limit imposed, has been exceeded(throttled)
          break unless batch_condition(record_ids.size, batch_size) && rate_limiting_condition(count, rate_limit[:batch_size])
        end
      end

      if rate_limit.present?
        klass = rate_limit[:class_name].constantize
        klass.perform_in(rate_limit[:run_after], rate_limit[:args]) unless rate_limiting_condition(count, rate_limit[:batch_size])
      end

      count
    end

    def find_in_batches_with_rate_limit(options = {})
      batch_count = 0
      rate_limit_options = options.delete(:rate_limit)
      options[:start] = rate_limit_options[:args][:primary_key_offset] if rate_limit_options[:args][:primary_key_offset].present?

      find_in_batches(options) do |records|
        yield records
        batch_count += records.size
        primary_key_offset = records.last.id
        return if rate_limit_find_in_batches(rate_limit_options, batch_count, primary_key_offset)
      end
    end

    def update_all_klass_name
      case klass.name
      when 'Helpdesk::SchemaLessTicket'
        'Helpdesk::Ticket'
      else
        self.klass.name
      end
    end

    def update_all_record_ids
      case klass.name
      when 'Helpdesk::SchemaLessTicket'
        self.map(&:ticket_id)
      else
        self.map(&:id)
      end
    end

    # performs update all with publish without batching of records
    def update_all_without_batching(updates_hash, options = {})
      publish_record_ids = self.update_all_record_ids
      Sharding.run_on_master do
        self.update_all(updates_hash)
      end
      UpdateAllPublisher.perform_async(klass_name: update_all_klass_name, ids: publish_record_ids, updates: updates_hash, options: options)
    end

    private

      def frame_converse_conditions(updates_hash)
        exclusion_fields = [:created_at, :updated_at, :blocked_at, :deleted_at]

        conditions = [[]]
        updates_hash.except(*exclusion_fields).each do |key, value|
          if value.nil?
            conditions[0].push("`#{key}` is not null")
          else
            conditions[0].push("`#{key}` != ?")
            conditions.push(value)
          end
        end
        conditions[0] = conditions[0].join(' and ')
        conditions
      end

      def batch_condition(records_count, batch_size)
        records_count == batch_size
      end

      def rate_limiting_condition(executed_count, current_batch_size)
        return true unless current_batch_size

        executed_count < current_batch_size
      end

      def rate_limit_find_in_batches(rate_limit_options, batch_count, primary_key_offset)
        return false if batch_count < rate_limit_options[:batch_size]

        klass = rate_limit_options[:class_name]
        rate_limit_options[:args][:primary_key_offset] = primary_key_offset + 1
        klass.constantize.perform_in(rate_limit_options[:run_after], rate_limit_options[:args])
      end
  end

  class Base
    attr_accessor :event_uuid

    after_commit :generate_event_id

    def generate_event_id
      self.event_uuid = UUIDTools::UUID.timestamp_create.hexdigest
    end

    class << self
      delegate :update_all_with_publish, to: :scoped
    end
  end
end
