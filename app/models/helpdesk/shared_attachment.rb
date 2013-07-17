class Helpdesk::SharedAttachment < ActiveRecord::Base

  set_table_name "helpdesk_shared_attachments"
  belongs_to :attachment, :class_name => 'Helpdesk::Attachment'
  belongs_to :shared_attachable, :polymorphic => true

  attr_protected  :account_id

  before_save :set_account_id

  def set_account_id
    self.account_id = shared_attachable.account_id if shared_attachable
  end

end
