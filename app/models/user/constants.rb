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

  MERGE_VALIDATIONS = [["emails", 5, "emails"], ["twitter_id", 1, "Twitter User"], 
    ["fb_profile_id", 1, "Facebook User"], ["external_id", 1, "Ecommerce User or Mobihelp User"], 
    ["company_names", 20, "companies"], ["mobile", 1, "mobile phone"], ["phone", 1, "work phone"]] #[Attribute, limit, message] ["phone", 1, "Phone User"]

  USER_FILTER_TYPES = ["verified","unverified","all","deleted","blocked"]

  MAX_USER_EMAILS = 5
  PASSWORD_LENGTH = 4
  MAX_USER_COMPANIES = 20

  ALPHA_NUMERIC_REGEX = /(?=.*\d)(?=.*[a-z])(?=.*[A-Z])/
  SPECIAL_CHARACTERS_REGEX = /(?=.*([\x20-\x2F]|[\x3A-\x40]|[\x5B-\x60]|[\x7B-\x7E]))/

  INLINE_MANUAL = {
    'admin_topic' => 3649,
    'agent_topic' => 6266
  }

end