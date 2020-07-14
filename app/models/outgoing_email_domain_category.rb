class OutgoingEmailDomainCategory < ActiveRecord::Base
  belongs_to_account

  serialize :dkim_config, Hash

  validates_uniqueness_of :email_domain, :scope => :account_id
  validate :domain_name

  after_commit :link_email_configs, on: :create
  before_save :remove_first_verify, on: :update

  has_many :email_configs
  has_many :dkim_records
  has_many :dkim_category_change_activities

  SMTP_CATEGORIES = {
    'trial' => 30,
    'active' => 31,
    'premium' => 32,
    'free' => 33,
    'default' => 34
  }

  STATUS = {
    'disabled' => 0,
    'unverified' => 1,
    'active' => 2,
    'delete' => 3
  }

  scope :active, :conditions => ["status != ?", STATUS['delete']]
  scope :dkim_configured_domains, :conditions => ["status in (?)", [STATUS['active'], STATUS['unverified']]]
  scope :dkim_activated_domains, :conditions => ["status = ?", STATUS['active']]
  scope :verified_email_configs_domain, conditions: ['email_configs.active', true], joins: [:email_configs], readonly: false

  INVALID_DOMAINS = ["freshdesk.com", "freshdesk-dev.com", "freshpo.com"]
  MAX_DKIM_ALLOWED = 2

  def domain_name
    self.errors[:base] << "Invalid domain." if INVALID_DOMAINS.include?(self.email_domain)
  end

  def self.active_domains
    active.order(:email_domain).includes(:dkim_records)
  end

  def link_email_configs
    self.account.all_email_configs.where("reply_email like (?)", "%@#{self.email_domain}").update_all(:outgoing_email_domain_category_id => self.id, :category => self.category)
  end
  
  def remove_first_verify
    if status_changed? and STATUS['active'] == self.status
      self.first_verified_at = nil
    end
  end
  
end
