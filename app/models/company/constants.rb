class Company < ActiveRecord::Base
  DEFAULT_DROPDOWN_FIELDS = [:default_health_score, :default_account_tier, :default_industry].freeze
  TAM_DEFAULT_FIELDS = [:default_health_score, :default_account_tier, :default_industry, :default_renewal_date].freeze

  DEFAULT_DROPDOWN_FIELD_MAPPINGS = {
    health_score: :default_health_score,
    account_tier: :default_account_tier,
    industry:     :default_industry
  }.freeze

  ENCRYPTED_VALUE_MASK = '********'.freeze

  TAM_DEFAULT_FIELD_MAPPINGS = {
    string_cc01:   :health_score,
    string_cc02:   :account_tier,
    string_cc03:   :industry,
    datetime_cc01: :renewal_date
  }.freeze

  CUST_TYPES = [
    [:customer, 'Customer', 1],
    [:prospect, 'Prospect', 2],
    [:partner,  'Partner',  3]
  ].freeze

  CUST_TYPE_OPTIONS   = CUST_TYPES.map { |i| [i[1], i[2]] }.freeze
  CUST_TYPE_BY_KEY    = Hash[*CUST_TYPES.map { |i| [i[2], i[1]] }.flatten].freeze
  CUST_TYPE_BY_TOKEN  = Hash[*CUST_TYPES.map { |i| [i[0], i[2]] }.flatten].freeze

  MAX_DISPLAY_COMPANY_TICKETS = 10
  MAX_DISPLAY_COMPANY_CONTACTS = 5
end
