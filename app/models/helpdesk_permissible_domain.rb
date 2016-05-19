class HelpdeskPermissibleDomain < ActiveRecord::Base
  include Cache::Memcache::Account  
  include UrlValidator

  belongs_to_account
  validates_presence_of :domain
  validates_uniqueness_of :domain, :scope => [:account_id]

  before_validation :downcase_and_strip
  before_validation :validate_permissible_domain
  after_commit :clear_helpdesk_permissible_domains_from_cache

  MAX_HELPDESK_PERMISSIBLE_DOMAINS = 40

  protected

  def downcase_and_strip
    self.domain = domain.downcase.strip if domain
  end

end
