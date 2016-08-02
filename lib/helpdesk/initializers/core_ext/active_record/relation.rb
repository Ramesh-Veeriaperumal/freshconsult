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

      begin
        records = self.where(filter_conditions).limit(batch_size).pluck(:id)  
        if records.present?
          updated_count = self.where(id: records).update_all(updates_hash)
          UpdateAllPublisher.perform_async(klass_name: self.klass.name, ids: records, updates: updates_hash)
          count = count + records.count
        end
      end while records.size == batch_size
      
      count
    end

    private
      
      def frame_converse_conditions(updates_hash)
        exclusion_fields = [:created_at, :updated_at, :blocked_at, :deleted_at]

        conditions = [[]]
        updates_hash.except(*exclusion_fields).each do |key ,value|
          if value.nil?
            conditions[0].push("`#{key}` is not null")
          else
            conditions[0].push("`#{key}` != ?")
            conditions.push(value)
          end
        end
        conditions[0] = conditions[0].join(" and ")
        conditions
      end

  end

  class Base
    class << self
      delegate :update_all_with_publish, :to => :scoped
    end
  end
end