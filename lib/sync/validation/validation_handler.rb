module Sync::Validation::ValidationHandler
  include Sync::Constants

  def perform_validation(diff)
    diff.each do |relation, rel_changes|
      rel_changes.each do |rel_change|
        next unless rel_change[:status] == :added

        Sharding.run_on_slave do
          perform_uniq_validation(relation, rel_change[:id], rel_change[:changes])
        end
      end
    end
    regenerate_diff(diff)
  end

  private

    def perform_uniq_validation(relation, id, changes)
      return unless changes.present? && relation.in?(UNIQUE_MODEL_DATA.keys)

      mod, uniq_columns, is_uniq_error = UNIQUE_MODEL_DATA[relation]
      uniq_columns_hash = {}
      idx = relation.in?(FORM_BASED_MODELS) ? -1 : 2
      changes.each do |change|
        attribute = change[:key].split('/')[idx]
        uniq_columns_hash[attribute] = change[:production_value] if attribute.in?(uniq_columns)
      end
      matching_record = ActiveRecord::Base.const_get(mod).where(uniq_columns_hash)
      return if matching_record.blank?

      error_message = {}
      error_message[relation] = {}
      error_message[relation][id] = {
        attributes: uniq_columns
      }
      error_message[relation][id][:conflict_type] = is_uniq_error ? :uniq_error : :error
      @validation_error.deep_merge!(error_message)
    end

    def regenerate_diff(diff)
      return diff if @validation_error.empty?

      validated_relations = @validation_error.keys
      diff.each do |relation, rel_changes|
        next unless relation.in?(validated_relations)

        validated_ids = @validation_error[relation].keys
        rel_changes.each do |rel_change|
          next unless rel_change[:id].in?(validated_ids)

          rel_change[:status] = :conflict
          validated_columns, conflict_type = @validation_error[relation][rel_change[:id]].map { |key, val| val }
          rel_change[:changes].each do |change|
            next unless change[:key].split('/')[-1].in?(validated_columns)

            if conflict_type
              change[:status] = :conflict
              change[:sandbox_value] = change[:production_value]
              rel_change[:meta] ||= {}
              rel_change[:meta][:conflict_type] = conflict_type
            end
          end
        end
      end
      diff
    end
end
