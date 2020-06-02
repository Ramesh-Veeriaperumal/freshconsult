module ContactFieldsConstants
  FOREGROUND_CONTACT_FIELDS = [
    { name: 'name',
      label: 'Full Name',
      required_for_agent: true,
      visible_in_portal: true,
      editable_in_portal: true,
      editable_in_signup: true,
      required_in_portal: true,
      position: 1 },

    { name: 'job_title',
      label: 'Title',
      visible_in_portal: true,
      editable_in_portal: true,
      position: 2 },

    { name: 'email',
      label: 'Email',
      visible_in_portal: true,
      editable_in_portal: false,
      editable_in_signup: true,
      required_in_portal: false,
      field_options: { 'widget_position' => 1 },
      position: 3 }, # default validations are present in User model(phone || twitter_id || email)

    { name: 'phone',
      label: 'Work Phone',
      visible_in_portal: true,
      editable_in_portal: true,
      field_options: { 'widget_position' => 2 },
      position: 4 },

    { name: 'company_name',
      label: 'Company',
      visible_in_portal: true,
      position: 7 },

    { name: 'time_zone',
      label: 'Time Zone',
      visible_in_portal: true,
      editable_in_portal: true,
      position: 9 },

    { name: 'language',
      label: 'Language',
      visible_in_portal: true,
      editable_in_portal: true,
      position: 10 }
  ].freeze

  BACKGROUND_CONTACT_FIELDS = [
    { name: 'mobile',
      label: 'Mobile Phone',
      visible_in_portal: true,
      editable_in_portal: true,
      field_options: { 'widget_position' => 3 },
      position: 5 },

    { name: 'twitter_id',
      label: 'Twitter',
      visible_in_portal: true,
      editable_in_portal: true,
      field_options: { 'widget_position' => 4 },
      position: 6 },

    { name: 'address',
      label: 'Address',
      position: 8 },

    { name: 'tag_names',
      label: 'Tags',
      position: 11 },

    { name: 'description',
      label: 'About',
      position: 12 },

    { name: 'client_manager',
      label: 'Can see all tickets from his company',
      position: 13 },

    { name: 'unique_external_id',
      label: 'Unique External Id',
      position: 14 },

    { name: 'twitter_profile_status',
      label: 'Twitter Verified Profile',
      position: 15 },

    { name: 'twitter_followers_count',
      label: 'Twitter Follower Count',
      position: 16 }
  ].freeze

  DEFAULT_CONTACT_FIELDS = FOREGROUND_CONTACT_FIELDS + BACKGROUND_CONTACT_FIELDS
end
