module CustomerNoteConstants
  CREATE_ARRAY_FIELDS = %w(attachments attachment_ids).freeze
  NOTE_CONSTANTS = %w(title body).freeze | CREATE_ARRAY_FIELDS # | AttachmentConstants::CLOUD_FILE_FIELDS
  CONTACT_NOTE_CONSTANTS = NOTE_CONSTANTS | %w(user_id).freeze
  COMPANY_NOTE_CONSTANTS = NOTE_CONSTANTS | %w(category_id company_id).freeze

  CONTACT_ADDITIONAL_INDEX_FIELDS = %w(contact_id next_id order_type).freeze
  COMPANY_ADDITIONAL_INDEX_FIELDS = %w(company_id next_id order_type).freeze
  DEFAULT_ORDER_BY = :created_at
  DEFAULT_ORDER_TYPE = 'desc'.freeze

  FIELD_MAPPINGS = { user_id: :contact_id }.freeze

  WRAP_PARAMS = [:note, exclude: [], format: [:json, :multipart_form]].freeze
  PARAMS_TO_SAVE_AND_REMOVE = [:attachment_ids].freeze # add :cloud_files to the array later
  VALIDATION_CLASS = 'CustomerNoteValidation'.freeze
  DELEGATOR_CLASS = 'CustomerNoteDelegator'.freeze
  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: %i(json multipart_form),
    update: %i(json multipart_form),
  }.freeze
end
