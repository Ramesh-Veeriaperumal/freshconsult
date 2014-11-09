class Helpdesk::SharedAttachment < ActiveRecord::Base

  self.table_name =  "helpdesk_shared_attachments"
  self.primary_key = :id
  belongs_to :attachment, :class_name => 'Helpdesk::Attachment'
  belongs_to :shared_attachable, :polymorphic => true

  attr_protected  :account_id

  belongs_to_account

  before_save :set_account_id

  belongs_to_account

  def set_account_id
    self.account_id = shared_attachable.account_id if shared_attachable
  end

end
