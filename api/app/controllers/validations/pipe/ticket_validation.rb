module Pipe
  class TicketValidation < ::TicketValidation
    # Appending to the existing constant
    CHECK_PARAMS_SET_FIELDS += %w(pending_since created_at updated_at on_state_time closed_at).freeze
    attr_accessor :pending_since, :created_at, :updated_at, :on_state_time, :closed_at

    # This will include the validations for created_at and updated_at
    include TimestampsValidationConcern

    # due_by and fr_due_by has to be checked with the given created_at time
    def due_by_gt_created_at
      errors[:due_by] << :gt_created_and_now if due_by < (created_at || @item.try(:created_at) || Time.zone.now)
    end

    def fr_due_gt_created_at
      errors[:fr_due_by] << :gt_created_and_now if fr_due_by < (created_at || @item.try(:created_at) || Time.zone.now)
    end

    # pending_since could be set only if created_at and updated_at are present and status is PENDING
    validates :pending_since, custom_absence: { message: :cannot_set_pending_since }, unless: :pending_since_allowed?

    # closed_at could be set only if created_at and updated_at are present and status is CLOSED
    validates :closed_at, custom_absence: { message: :cannot_set_closed_at }, unless: :closed_at_allowed?

    validates :pending_since, :closed_at, date_time: { allow_nil: false }
    validate :validate_pending_since, if: -> { pending_since && errors[:pending_since].blank? }
    validate :validate_closed_at, if: -> { closed_at && errors[:closed_at].blank? }

    validates :on_state_time, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }

    def pending_since_allowed?
      created_at && updated_at && status.respond_to?(:to_i) && status.to_i == ApiTicketConstants::PENDING
    end

    def validate_pending_since
      if pending_since > Time.zone.now
        errors[:pending_since] << :start_time_lt_now
      elsif pending_since < created_at
        errors[:pending_since] << :gt_created_and_now
      end
    end

    def closed_at_allowed?
      created_at && updated_at && status.respond_to?(:to_i) && status.to_i == ApiTicketConstants::CLOSED
    end

    def validate_closed_at
      if closed_at > Time.zone.now
        errors[:closed_at] << :start_time_lt_now
      elsif closed_at < created_at
        errors[:closed_at] << :gt_created_and_now
      end
    end
  end
end
