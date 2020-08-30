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
                  :fb_profile_id,:external_id,:language,:address,:unique_external_id]
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
  PROTECTED_ATTRIBUTES = ['email', 'password', 'password_confirmation', 'primary_email_attributes',
                          'user_emails_attributes', 'customer_id', 'client_manager',
                          'helpdesk_agent', 'role_ids', 'customer_attributes', 'company_name', 'company_id']

  USER_SECONDARY_ATTRIBUTES = ["twitter_id", "avatar", "time_zone", "phone", "mobile", "fb_profile_id", "address",
                               "external_id", "job_title", "language", "description", "unique_external_id",
                               'twitter_profile_status', 'twitter_followers_count', 'twitter_requester_handle_id'] # client_manager will be moved directly

  MAX_USER_EMAILS = 10
  MAX_USER_COMPANIES = 300

  MERGE_VALIDATIONS = [['emails', MAX_USER_EMAILS, 'emails'],
                       ['twitter_id', 1, 'Twitter User'],
                       ['fb_profile_id', 1, 'Facebook User'],
                       ['external_id', 1, 'Ecommerce User or Mobihelp User'],
                       ['mobile', 1, 'mobile phone'],
                       ['phone', 1, 'work phone'],
                       ['unique_external_id', 1, 'Unique external id']].freeze
  # [Attribute, limit, message] ['phone', 1, 'Phone User']

  USER_FILTER_TYPES = %w(verified unverified all deleted blocked).freeze

  PASSWORD_LENGTH = 4

  ALPHA_NUMERIC_REGEX = /(?=.*\d)(?=.*[a-z])(?=.*[A-Z])/
  SPECIAL_CHARACTERS_REGEX = /(?=.*([\x20-\x2F]|[\x3A-\x40]|[\x5B-\x60]|[\x7B-\x7E]))/

  INLINE_MANUAL = {
    'admin_topic' => 3649,
    'agent_topic' => 6266
  }.freeze

  MAX_NO_OF_SKILLS_PER_USER = 35

  ACTIVATION_ATTRIBUTES = [:name, :mobile, :phone, :job_title, :password, :password_confirmation].freeze
  ADMIN_PRIVILEGES = [:view_admin]

  CONTACT_FILTER_MAPPING = {
    all: { deleted: false, blocked: false },
    verified: { deleted: false, active: true, blocked: false },
    unverified: { deleted: false, active: false, blocked: false },
    deleted: { deleted: true, blocked: false }
  }.freeze

  PROFILE_UPDATE_ATTRIBUTES = [:name, :email, :customer_id, :job_title, :second_email, :phone, 
    :mobile, :twitter_id, :description, :time_zone, :deleted, :deleted_at, :fb_profile_id, 
    :language, :address, :external_id, :unique_external_id, :perishable_token]

  FRESHID_IGNORED_EMAIL_IDS = ["custserv@freshdesk.com"]
  CONTACT_NAME_SANITIZER_REGEX = /www\..*|\/|"/.freeze
  CONTACT_COMPANY_PRIVILEGES_SPLIT = [:manage_companies, :delete_company].freeze
  HARD_DELETE_DELAY = 1.minute
end
