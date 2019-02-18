class DataExport < ActiveRecord::Base
  self.primary_key = :id
  belongs_to_account
  belongs_to :user

  has_one :attachment,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy
  
  EXPORT_TYPE = { :backup => 1, :ticket => 2, :contact => 3, :company => 4, :call_history => 5, :agent => 6, :reports => 7, 
                  :archive_ticket => 8, audit_log: 9 }

  TICKET_EXPORT_LIMIT = 3
  PAID_TICKET_EXPORT_LIMIT = 10
  
  CONTACT_EXPORT_LIMIT_PER_ACCOUNT = 1
  COMPANY_EXPORT_LIMIT_PER_ACCOUNT = 1
  OLD_BACKUP_UPPER_THRESHOLD_DAYS = 30
  OLD_BACKUP_LOWER_THRESHOLD_DAYS = 60

  AUDIT_LOG_EXPORT_LIMIT = 1

  EXPORT_STATUS = {:started => 1,
                   :file_created => 2,
                   :file_uploaded => 3,
                   :completed => 4,
                   :failed => 5}

  EXPORT_IN_PROGRESS_STATUS = [:started, :file_created, :file_upload].freeze

  scope :ticket_export, :conditions => { :source => EXPORT_TYPE[:ticket] }, :order => "id"
  scope :data_backup, conditions: { source: EXPORT_TYPE[:backup] }, :limit => 1, order: 'id desc'
  scope :contact_export, :conditions => { :source => EXPORT_TYPE[:contact] }, :order => "id"
  scope :company_export, :conditions => { :source => EXPORT_TYPE[:company] }, :order => "id"
  scope :call_history_export, :conditions => { :source => EXPORT_TYPE[:call_history] }
  scope :agent_export, :conditions => { :source => EXPORT_TYPE[:agent] }, :order => "id"
  scope :reports_export, :conditions => { :source => EXPORT_TYPE[:reports] }, :order => "id"
  scope :audit_log_export, conditions: { source: EXPORT_TYPE[:audit_log] }
  scope :current_exports, :conditions => ["status = #{EXPORT_STATUS[:started]} and last_error is null"]
  scope :running_ticket_exports, :conditions => ["source = #{EXPORT_TYPE[:ticket]} and status NOT in (?)", [EXPORT_STATUS[:completed], EXPORT_STATUS[:failed]]]
  scope :running_archive_ticket_exports, :conditions => ["source = #{EXPORT_TYPE[:archive_ticket]} and status NOT in (?)", [EXPORT_STATUS[:completed], EXPORT_STATUS[:failed]]]
  scope :running_contact_exports, conditions: ["source = #{EXPORT_TYPE[:contact]} and status NOT in (?)", [EXPORT_STATUS[:completed], EXPORT_STATUS[:failed]]]
  scope :running_company_exports, conditions: ["source = #{EXPORT_TYPE[:company]} and status NOT in (?)", [EXPORT_STATUS[:completed], EXPORT_STATUS[:failed]]]
  scope :running_audit_log_exports, conditions: ["source = #{EXPORT_TYPE[:audit_log]} and status NOT in (?)", [EXPORT_STATUS[:completed], EXPORT_STATUS[:failed]]]
  scope :old_data_backup, lambda{ |threshold = OLD_BACKUP_UPPER_THRESHOLD_DAYS.days.ago| { 
    conditions: ["source = #{EXPORT_TYPE[:backup]} and created_at <= (?) and created_at >= (?)", 
      threshold, OLD_BACKUP_LOWER_THRESHOLD_DAYS.days.ago] }}


  def owner?(downloader)
    user_id && downloader && (user_id == downloader.id)
  end

  def started!
    self.update_attributes(:status => EXPORT_STATUS[:started])
  end

  def file_created!
    self.update_attributes(:status => EXPORT_STATUS[:file_created])
  end

  def file_uploaded!
    self.update_attributes(:status => EXPORT_STATUS[:file_uploaded])
  end

  def completed!
    self.update_attributes(:status => EXPORT_STATUS[:completed])
  end

  def failure!(error)
    self.update_attributes(:last_error => error, :status => EXPORT_STATUS[:failed])
  end

  def completed?
    [EXPORT_STATUS[:completed], 0].include? status
  end

  def failed?
    status == EXPORT_STATUS[:failed]
  end

  def save_hash!(hash)
    self.update_attributes(:token => hash)
  end

  def self.default_export_limit
    Account.current.subscription.paid_account? ? PAID_TICKET_EXPORT_LIMIT : TICKET_EXPORT_LIMIT
  end

  def self.ticket_export_limit
    Account.current.account_additional_settings.ticket_exports_limit || default_export_limit
  end

  def self.archive_ticket_export_limit
    Account.current.account_additional_settings.archive_ticket_exports_limit || default_export_limit
  end

  def self.contact_export_limit
    Account.current.account_additional_settings.contact_exports_limit || CONTACT_EXPORT_LIMIT_PER_ACCOUNT
  end

  def self.company_export_limit
    Account.current.account_additional_settings.company_exports_limit || COMPANY_EXPORT_LIMIT_PER_ACCOUNT
  end

  def self.ticket_export_limit_reached?(user)
    user.data_exports.running_ticket_exports.count >= self.ticket_export_limit
  end

  def self.archive_ticket_export_limit_reached?
    Account.current.data_exports.running_archive_ticket_exports.count >= self.archive_ticket_export_limit
  end

  def self.contact_export_limit_reached?
    Account.current.data_exports.running_contact_exports.count >= contact_export_limit
  end

  def self.company_export_limit_reached?
    Account.current.data_exports.running_company_exports.count >= company_export_limit
  end

  def self.audit_log_export_limit_reached?
    export = Account.current.data_exports.running_audit_log_exports.last
    export.present? && export.status == 1
  end
end
