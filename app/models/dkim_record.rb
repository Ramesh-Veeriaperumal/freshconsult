class DkimRecord < ActiveRecord::Base

  belongs_to :outgoing_email_domain_category

  attr_accessible :sg_id, :sg_user_id, :sg_type, :record_type, :host_name, :host_value, :status, :account_id, :customer_record

  CUSTOM_RECORDS = ['dkim', 'subdomain_spf', 'mail_server']

  scope :filter_records, :conditions => ["sg_type != 'mail_cname'"]
  scope :custom_records, :conditions => ["sg_type in (?)", CUSTOM_RECORDS]
  scope :default_records, :conditions => ["sg_type NOT in (?)", CUSTOM_RECORDS]
  scope :customer_records, :conditions => ["customer_record = true"]
  scope :non_active_records, :conditions => ["status = false"]
  
  def self.filter_customer_records
    customer_records.order("record_type DESC")
  end
end
