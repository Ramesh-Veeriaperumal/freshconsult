module TimestampsValidationConcern
  extend ActiveSupport::Concern

  # This module will perform the validation for created_at and updated_at
  #
  # The validation logic:
  #     1] Both created_at and updated_at must be present
  #     2] created_at and updated_at must be in valid date_time format
  #     3] created_at and updated_at should not be greater than the current time
  #     4] updated_at >= created_at
  #
  # The assumptions are:
  #     1] created_at and updated_at should only be exposed for create endpoint
  #
  # To include this into the validation, add created_at & updated_at as attr_accessor
  # and CHECK_PARAMS_SET_FIELDS in the validation file and CREATE_FIELDS in the constants module

  included do
    validates :created_at, custom_absence: {
      message: :dependent_timestamp_missing,
      message_options: {
        dependent_timestamp: :updated_at
      },
      code: :missing_field
    }, unless: :updated_at
    validates :updated_at, custom_absence: {
      message: :dependent_timestamp_missing,
      message_options: {
        dependent_timestamp: :created_at
      },
      code: :missing_field
    }, unless: :created_at

    validates :created_at, :updated_at, date_time: { allow_nil: true }
    validate :validate_created_at, if: :created_at_present?
    validate :validate_updated_at, if: :updated_at_present?
  end

  def validate_created_at
    errors[:created_at] << :start_time_lt_now unless valid_timestamp?(created_at)
  end

  def validate_updated_at
    if errors[:created_at].blank? && !valid_timestamp?(created_at, updated_at)
      errors[:updated_at] << :gt_created_and_now
    elsif !valid_timestamp?(updated_at)
      errors[:updated_at] << :start_time_lt_now
    end
  end

  def created_at_present?
    created_at && errors[:created_at].blank?
  end

  def updated_at_present?
    updated_at && errors[:updated_at].blank?
  end

  def valid_timestamp?(time_a, time_b = Time.zone.now)
    time_a.to_time.utc <= time_b.to_time.utc
  end
end
