class Admin::DataImport < ActiveRecord::Base
  self.primary_key = :id

  include Import::Zen::Redis

  after_destroy :clear_key, :if => :zendesk_import?
  
  before_destroy :clear_attachments, if: -> { !Account.current.secure_attachments_enabled? }

  self.table_name =  "admin_data_imports"    
  
  belongs_to :account

  has_many :attachments,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment'
  
  IMPORT_TYPE = { zendesk: 1, contact: 2, company: 3, agent_skill: 4, outreach_contact: 5 }.freeze

  IMPORT_STATUS = { started: 1,
                    completed: 2,
                    file_created: 3,
                    blocked: 4,
                    failed: 5,
                    cancelled: 6 }.freeze

  IN_PROGRESS_STATUS = [:started, :file_created].freeze

  scope :running_contact_imports, -> {
    where(['source = ? and import_status in (?)', 
              IMPORT_TYPE[:contact],
              [IMPORT_STATUS[:started], IMPORT_STATUS[:file_created]]])
  }

  scope :running_company_imports, -> {
    where(['source = ? and import_status in (?)', 
            IMPORT_TYPE[:company],
            [IMPORT_STATUS[:started], IMPORT_STATUS[:file_created]]])
  }

  def completed!
    update_attributes(import_status: IMPORT_STATUS[:completed])
  end

  def file_creation!
    update_attributes(import_status: IMPORT_STATUS[:file_created])
  end

  def blocked!
    update_attributes(import_status: IMPORT_STATUS[:blocked])
  end

  def failure!(error)
    update_attributes(import_status: IMPORT_STATUS[:failed], last_error: error)
  end

  def cancelled!
    update_attributes(import_status: IMPORT_STATUS[:cancelled])
  end

  private

  def clear_key
    clear_redis_key
  end

  def zendesk_import?
    source == IMPORT_TYPE[:zendesk]
  end

  def clear_attachments
    self.attachments.destroy_all
  end
end
