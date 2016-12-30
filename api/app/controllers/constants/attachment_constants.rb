module AttachmentConstants
  # Controller constants
  CREATE_FIELDS = %w(user_id content inline inline_type).freeze

  CLOUD_FILE_FIELDS = [cloud_files: [:url, :filename, :application_id]].freeze

  STANDALONE_ATTACHMENT_TYPE = 'UserDraft'.freeze

  INLINE_ATTACHABLE_TYPES = [
    [ :ticket,              'Tickets Image',            1 ],
    [ :forum,               'Forums Image',             2 ],
    [ :solution,            'Image',                    3 ],
    [ :email_notification,  'Email Notification Image', 4 ],
    [ :template,            'Templates Image',          5 ]
  ]

  INLINE_ATTACHABLE_NAMES_BY_KEY = Hash[*INLINE_ATTACHABLE_TYPES.map { |i| [i[2], i[1]] }.flatten]
  INLINE_ATTACHABLE_TOKEN_BY_KEY = Hash[*INLINE_ATTACHABLE_TYPES.map { |i| [i[2], i[0]] }.flatten]

  # Only xxx.jpg and xxx.png are allowed to upload
  INLINE_IMAGE_EXT = %w(.jpg .jpeg .jpe .png .gif).freeze

  # Wrap parameters args
  WRAP_PARAMS = [:attachment, exclude: [], format: [:json, :multipart_form]].freeze

  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:multipart_form]
  }.freeze

  PARAMS_MAPPINGS = { user_id: :attachable_id }.freeze
  PARAMS_TO_REMOVE = [:inline, :inline_type].freeze

  VALIDATION_CLASS = 'AttachmentValidation'.freeze
  DELEGATOR_CLASS = 'AttachmentDelegator'.freeze
end.freeze
