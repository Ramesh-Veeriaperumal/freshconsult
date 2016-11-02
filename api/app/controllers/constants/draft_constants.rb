module DraftConstants
  # ControllerConstants
  SAVE_DRAFT_ARRAY_FIELDS = %w(cc_emails bcc_emails attachment_ids).freeze
  SAVE_DRAFT_FIELDS = %w(body from_email).freeze | SAVE_DRAFT_ARRAY_FIELDS
  EMAIL_FIELDS = [:cc_emails, :bcc_emails, :from_email].freeze

  PERMISSION_REQUIRED = [:save_draft, :show_draft, :clear_draft].freeze
  LOAD_OBJECT_EXCEPT = [:save_draft, :show_draft, :clear_draft].freeze

  # Wrap parameters args
  WRAP_PARAMS = [:draft, exclude: [], format: [:json]].freeze

  REDIS_MAX_ATTEMPTS = 3

  VALIDATION_CLASS = 'DraftValidation'.freeze
  DELEGATOR_CLASS = 'DraftDelegator'.freeze
end.freeze
