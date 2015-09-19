# encoding: utf-8
class User < ActiveRecord::Base

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
                                "external_id", "job_title", "language", "description"] #client_manager will be moved directly

  MERGE_VALIDATIONS = [["emails", 5], ["twitter_id", 1], ["fb_profile_id", 1]] #[Attribute, limit] ["phone", 1]

  USER_FILTER_TYPES = ["verified","unverified","all","deleted","blocked"]

  MAX_USER_EMAILS = 5
  PASSWORD_LENGTH = 4

  ALPHA_NUMERIC_REGEX = /(?=.*\d)(?=.*[a-z])(?=.*[A-Z])/
  SPECIAL_CHARACTERS_REGEX = /(?=.*([\x20-\x2F]|[\x3A-\x40]|[\x5B-\x60]|[\x7B-\x7E]))/
end