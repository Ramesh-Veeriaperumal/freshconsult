module ContactConstants
  CONTACT_ARRAY_FIELDS = [{ 'tags' => [String] }]
  UPDATE_CONTACT_FIELDS = { all: %w(address avatar client_manager company_id description email job_title language mobile name phone time_zone twitter_id) | CONTACT_ARRAY_FIELDS }
  CREATE_CONTACT_FIELDS = { all: %w(address avatar client_manager company_id description email job_title language mobile name phone time_zone twitter_id) | CONTACT_ARRAY_FIELDS }

  CONTACT_STATES = %w( verified unverified all deleted blocked )

  INDEX_CONTACT_FIELDS = %w( state email phone mobile company_id )

  DELETED_SCOPE = {
    'update' => false,
    'restore' => true,
    'destroy' => false,
    'make_agent' => false,
  }

  # Based on limitation specified in Helpdesk::Attachment ( def image? )
  ALLOWED_AVATAR_SIZE = 5 * 1024 * 1024
  UPLOADED_FILE_TYPE = ActionDispatch::Http::UploadedFile
end