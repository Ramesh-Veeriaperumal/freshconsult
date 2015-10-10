class Helpdesk::CloudFile < ActiveRecord::Base

  self.table_name =  "helpdesk_dropboxes"
  self.primary_key = :id

  belongs_to :droppable, :polymorphic => true
  belongs_to :application, :class_name => "Integrations::Application"
  belongs_to_account

  # You don't need this callback 
  before_save :set_account_id

  alias_attribute :parent_type, :droppable_type

  def to_liquid
   @helpdesk_cloud_file_drop ||= Helpdesk::CloudFileDrop.new self
  end

  def serialize
    h( {:name => filename, :link => url, :provider => provider}.to_json )
  end

  def provider
    self.application.name
  end

  def filename
    read_attribute(:filename) || URI.unescape(url.split('/')[-1])
  end

  def object_type
    :droppable
  end

  private

  # Bad code need to remove 
  def set_account_id
    self.account_id ||= droppable.account_id
  end

  CLOUD_FILE_PROVIDERS = ['dropbox']
end