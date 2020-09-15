module AttachmentConstants
  # Controller constants
  CREATE_FIELDS = %w[user_id content inline inline_type description].freeze
  UNLINK_FIELDS = %w[attachable_id attachable_type].freeze

  CLOUD_FILE_FIELDS = [cloud_files: [:url, :name, :application_id]].freeze

  STANDALONE_ATTACHMENT_TYPE = 'UserDraft'.freeze

  WIDGET_ATTACHMENT_TYPE = 'WidgetDraft'.freeze

  FILE_TICKET_FIELD = 'Helpdesk::FileTicketField'.freeze

  INLINE_ATTACHABLE_TYPES = [
    [:ticket,              'Tickets Image',            1],
    [:forum,               'Forums Image',             2],
    [:solution,            'Image',                    3],
    [:email_notification,  'Email Notification Image', 4],
    [:template,            'Templates Image',          5]
  ].freeze

  INLINE_ATTACHABLE_NAMES_BY_KEY = Hash[*INLINE_ATTACHABLE_TYPES.map { |i| [i[2], i[1]] }.flatten]
  INLINE_ATTACHABLE_TOKEN_BY_KEY = Hash[*INLINE_ATTACHABLE_TYPES.map { |i| [i[2], i[0]] }.flatten]
  INLINE_ATTACHABLE_NAMES_BY_TOKEN = Hash[*INLINE_ATTACHABLE_TYPES.map { |i| [i[0], i[1]] }.flatten]

  ATTACHABLE_TYPES = {
    'ticket'           => 'Helpdesk::Ticket',
    'conversation'     => 'Helpdesk::Note',
    'canned_response'  => 'Admin::CannedResponses::Response',
    'ticket_template'  => 'Helpdesk::TicketTemplate',
    'solution_article' => 'Solution::Article',
    'solution_draft'   => 'Solution::Draft',
    'post'             => 'Post',
    'user'             => 'User',
    'company'          => 'Company',
    'user_draft'       => 'UserDraft',
    'account'          => 'Account',
    'portal'           => 'Portal',
    'widget_draft'     => 'WidgetDraft'
  }.freeze

  ATTACHMENT_DESCRIPTION = {
    'helpdesk_logo' => 'helpdesk_logo'
  }.freeze

  CLONEABLE_ATTACHMENT_TYPES = [
    'Account', 'Admin::CannedResponses::Response', 'Solution::Article', 'Helpdesk::TicketTemplate'
  ].freeze

  # Only xxx.jpg and xxx.png are allowed to upload
  INLINE_IMAGE_EXT = %w[.jpg .jpeg .jpe .png .gif .tiff].freeze

  LOAD_OBJECT_EXCEPT = %w[unlink].freeze

  # Wrap parameters args
  WRAP_PARAMS = [:attachment, exclude: [], format: [:json, :multipart_form]].freeze

  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:multipart_form],
    unlink: [:json]
  }.freeze

  PARAMS_MAPPINGS = { user_id: :attachable_id }.freeze
  PARAMS_TO_REMOVE = [:inline, :inline_type].freeze
  CLOUD_FILE_PARAMS_MAPPING = { name: :filename }.freeze

  VALIDATION_CLASS = 'AttachmentValidation'.freeze
  DELEGATOR_CLASS = 'AttachmentDelegator'.freeze

  BLOB_MAPPING = {
    'image/jpeg' => '.jpg',
    'image/jpg' => '.jpg',
    'image/png' => '.png',
    'image/gif' => '.gif',
    'image/tiff' => '.tiff'
  }.freeze

  WIDGET_ATTACHMENT_FIELDS = %w[content].freeze
end.freeze
