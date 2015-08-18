module ContactConstants
  ARRAY_FIELDS = [{ 'tags' => [String] }]
  UPDATE_FIELDS = { all: %w(address avatar client_manager company_id description email job_title language mobile name phone time_zone twitter_id tags) | ARRAY_FIELDS }
  CREATE_FIELDS = { all: %w(address avatar client_manager company_id description email job_title language mobile name phone time_zone twitter_id tags) | ARRAY_FIELDS }

  STATES = %w( verified unverified all deleted blocked )

  INDEX_FIELDS = %w( state email phone mobile company_id )

  DELETED_SCOPE = {
    'update' => false,
    'restore' => true,
    'destroy' => false,
    'make_agent' => false
  }

  # Based on limitation specified in Helpdesk::Attachment ( def image? )
  ALLOWED_AVATAR_SIZE = 5 * 1024 * 1024
  UPLOADED_FILE_TYPE = ActionDispatch::Http::UploadedFile
end
