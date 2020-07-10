class DataExport < ActiveRecord::Base
  self.primary_key = :id
  belongs_to_account
  belongs_to :user

  serialize :export_params, Hash

  has_one :attachment,
          as: :attachable,
          class_name: 'Helpdesk::Attachment',
          dependent: :destroy

  EXPORT_TYPE = { backup: 1, ticket: 2, contact: 3, company: 4, call_history: 5, agent: 6, reports: 7,
                  archive_ticket: 8, audit_log: 9, article: 10, ticket_shadow: 11 }.freeze
  EXPORT_NAME_BY_TYPE = EXPORT_TYPE.invert.freeze

  TICKET_EXPORT_LIMIT = 3
  PAID_TICKET_EXPORT_LIMIT = 10

  ARTICLE_EXPORT_LIMIT = 3

  CONTACT_EXPORT_LIMIT_PER_ACCOUNT = 1
  COMPANY_EXPORT_LIMIT_PER_ACCOUNT = 1
  OLD_BACKUP_UPPER_THRESHOLD_DAYS = 30
  OLD_BACKUP_LOWER_THRESHOLD_DAYS = 60

  AUDIT_LOG_EXPORT_LIMIT = 1

  EXPORT_STATUS = { started: 1,
                    file_created: 2,
                    file_uploaded: 3,
                    completed: 4,
                    failed: 5,
                    no_logs: 6 }.freeze

  EXPORT_IN_PROGRESS_STATUS = [:started, :file_created, :file_upload].freeze

  EXPORT_COMPLETED_STATUS = [4, 5, 6].freeze

  [:ticket, :contact, :company, :call_history, :agent, :reports, :audit_log, :ticket_shadow].each do |type|
    scope :"#{type}_export", -> { where(source: EXPORT_TYPE[type]).order(:id) }
  end

  scope :data_backup, -> { 
    where(source: EXPORT_TYPE[:backup]).
    order('id desc').
    limit(1) 
  }

  scope :current_exports, -> { 
    where(
      source: EXPORT_TYPE[:started],
      last_error: nil
    )
  }

  [:ticket, :contact, :company, :archive_ticket, :article].each do |type|
    scope :"running_#{type}_exports", -> { 
      where(["source = ? AND status NOT in (?)",
              EXPORT_TYPE[type],  [EXPORT_STATUS[:completed], EXPORT_STATUS[:failed]]
            ]
      )
    }
  end

  scope :old_data_backup, -> (threshold  = OLD_BACKUP_UPPER_THRESHOLD_DAYS.days.ago) {
    where(["source = ? and created_at <= (?) and created_at >= (?)", 
            EXPORT_TYPE[:backup], threshold, OLD_BACKUP_LOWER_THRESHOLD_DAYS.days.ago])
  }

  EXPORT_TYPE.each do |export_name, export_enum|
    define_method("#{export_name}_export?") do
      source == export_enum
    end
  end

  def owner?(downloader)
    user_id && downloader && (user_id == downloader.id)
  end

  def started!
    update_attributes(status: EXPORT_STATUS[:started])
  end

  def file_created!
    update_attributes(status: EXPORT_STATUS[:file_created])
  end

  def file_uploaded!
    update_attributes(status: EXPORT_STATUS[:file_uploaded])
  end

  def completed!
    update_attributes(status: EXPORT_STATUS[:completed])
  end

  def failure!(error)
    update_attributes(last_error: error, status: EXPORT_STATUS[:failed])
  end

  def no_logs!
    update_attributes(status: EXPORT_STATUS[:no_logs])
  end

  def completed?
    [EXPORT_STATUS[:completed], 0].include? status
  end

  def failed?
    status == EXPORT_STATUS[:failed]
  end

  def save_hash!(hash)
    update_attributes(token: hash)
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

  def self.article_export_limit_reached?(user)
    user.data_exports.running_article_exports.count >= ARTICLE_EXPORT_LIMIT
  end

  def self.contact_export_limit_reached?
    Account.current.data_exports.running_contact_exports.count >= contact_export_limit
  end

  def self.company_export_limit_reached?
    Account.current.data_exports.running_company_exports.count >= company_export_limit
  end

  def self.audit_log_export_limit_reached?
    export = Account.current.data_exports.audit_log_export.last
    export && export.status && EXPORT_COMPLETED_STATUS.exclude?(export.status) && export.token
  end
end
