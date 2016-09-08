module AttachmentConstants
  # Controller constants
  CREATE_FIELDS = %w(user_id content).freeze

  STANDALONE_ATTACHMENT_TYPE = 'UserDraft'.freeze

  # Wrap parameters args
  WRAP_PARAMS = [:attachment, exclude: [], format: [:json, :multipart_form]].freeze

  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:multipart_form]
  }.freeze

  FIELD_MAPPINGS = { user_id: :attachable_id }.freeze
end.freeze
