module Concerns::ActsAsListPositionUpdate
  extend ActiveSupport::Concern

  included do
    before_update :reorder_relative_position, if: -> { position_changed? && condition_valid? }

    private

      # calling it manually to avoid deadlock/failure instead of using acts_as_list on update
      # logic behind this - In case of duplicate position, it will not reorder properly/ not stable reordering.
      # 1) decrement all the data below its old/current position(position >= old_position)
      # 2) set the current object position as null
      # 3) increment all the data below its new position(position >= new_position)
      # 4) assign the new position
      def reorder_relative_position
        old_position = changes[:position][0]
        new_position = changes[:position][1] || 1 # move always to first position

        Rails.logger.info "----Triggering relative position update-----From #{old_position} to #{new_position}"
        # moving all the ticket_field upwards by 1 relative to current field old position
        acts_as_list_class.where(scope_condition).where(['position >= ?', old_position]).update_all('position = (position - 1)') if old_position.present?
        update_column(:position, nil) # making it null to avoid including in below update
        increment_positions_on_lower_items(new_position) # moving all the ticket field downward by 1 relative to new position
        update_column(:position, new_position) # update to new position
      end

      def condition_valid?
        true
      end
  end
end
