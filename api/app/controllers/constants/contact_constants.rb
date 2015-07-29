module ContactConstants
  CONTACT_ARRAY_FIELDS = [{ 'tags' => [String] }]
  CONTACT_FIELDS = %w(address avatar_attributes client_manager company_id description email fb_profile_id job_title language mobile name phone time_zone twitter_id) | CONTACT_ARRAY_FIELDS

  CONTACT_FILTER = %w( verified unverified all deleted blocked )

  INDEX_CONTACT_FIELDS = %w( state email phone mobile company_id )

  DELETED_SCOPE = {
    'update' => false,
    'restore' => true,
    'destroy' => false,
    'make_agent' => false,
  }
end