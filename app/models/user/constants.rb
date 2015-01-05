# encoding: utf-8
class User < ActiveRecord::Base

  EMAIL_REGEX = /(\A[-A-Z0-9.'’_&%=+]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,15})\z)/i

  USER_ROLES = [
     [ :admin,       "Admin",            1 ],
     [ :poweruser,   "Power User",       2 ],
     [ :customer,    "Customer",         3 ],
     [ :account_admin,"Account admin",   4 ],
     [ :client_manager,"Client Manager", 5 ],
     [ :supervisor,    "Supervisor"    , 6 ]
    ]

  COMMON_API_OPTIONS = { 
    :only     => [:id,:name,:email,:created_at,:updated_at,:active,:customer_id,:job_title,
                  :phone,:mobile,:twitter_id,:description,:time_zone,:deleted,:helpdesk_agent,
                  :fb_profile_id,:external_id,:language,:address]
  }

  USER_API_OPTIONS = { 
    :only     => COMMON_API_OPTIONS[:only],
    :methods  => [:company_id]
  }

  CONTACT_API_OPTIONS = { 
    :only     => COMMON_API_OPTIONS[:only],
    :methods  => [:company_id, :custom_field]
  }

  # For preventing non-agents from updating inaccessible user attibutes
  PROTECTED_ATTRIBUTES = ["email", "password", "password_confirmation", "primary_email_attributes", 
                          "user_emails_attributes", "customer_id", "client_manager", 
                          "helpdesk_agent", "role_ids", "customer_attributes", "company_name"]

  USER_SECONDARY_ATTRIBUTES = ["twitter_id", "avatar", "time_zone", "phone", "mobile", "fb_profile_id", "address",
                                "external_id", "job_title", "language"]

  ES_CONTACT_FIELD_DATA_COLUMNS = ContactFieldData.column_names.select{ |column_name| 
                                    column_name =~ /^cf_(str|text|int|decimal|date)/}.map &:to_s
  ES_COLUMNS = ['name', 'email', 'description', 'job_title', 'phone', 'mobile', 'twitter_id', 
      'fb_profile_id', 'customer_id', 'deleted', 'helpdesk_agent'].concat(ES_CONTACT_FIELD_DATA_COLUMNS)

end