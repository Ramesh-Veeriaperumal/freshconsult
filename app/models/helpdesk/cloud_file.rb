class Helpdesk::CloudFile < ActiveRecord::Base

  self.primary_key = :id

  belongs_to :droppable, :polymorphic => true
  belongs_to :application, :class_name => "Integrations::Application"

  self.table_name =  "helpdesk_dropboxes"

  belongs_to_account

  before_save :set_account_id

  def to_liquid
   @helpdesk_cloud_file_drop ||= Helpdesk::CloudFileDrop.new self
  end

  def serialize
    h( {:name => filename, :link => url, :provider => provider}.to_json )
  end

  def provider
    Integrations::Application.find_by_id(application_id).name
  end

  def filename
    read_attribute(:filename) || URI.unescape(url.split('/')[-1])
  end

  def parent_type
    droppable_type
  end

  def object_type
    :droppable
  end

  private

  def set_account_id
    self.account_id = droppable.account_id
  end

  CLOUD_FILE_PROVIDERS = ['dropbox']
end