class DataExport < ActiveRecord::Base
  self.primary_key = :id
  belongs_to_account
  belongs_to :user

  has_one :attachment,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy
  
  EXPORT_TYPE = { :backup => 1, :ticket => 2 }

  TICKET_EXPORT_LIMIT = 3

  EXPORT_STATUS = { :started => 1, 
                    :file_created => 2,
                    :file_uploaded => 3,
                    :completed => 4 }

  scope :ticket_export, :conditions => { :source => EXPORT_TYPE[:ticket] }
  scope :data_backup, :conditions => { :source => EXPORT_TYPE[:backup] }, :limit => 1 

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
    self.update_attributes(:last_error => error)
  end

  def completed?
    [EXPORT_STATUS[:completed], 0].include? status
  end

  def save_hash!(hash)
    self.update_attributes(:token => hash)
  end

end
