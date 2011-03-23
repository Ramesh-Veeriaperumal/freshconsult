class EmailConfig < ActiveRecord::Base
  belongs_to :account
  belongs_to :group, :foreign_key =>'group_id' #?!?!?! Not a literal belonging in true ER sense.
  
  #accepts_nested_attributes_for :group
  attr_accessible :to_email, :reply_email, :group_id, :primary_role
  
  validates_presence_of :to_email, :reply_email
  validates_uniqueness_of :to_email, :scope => :account_id

end
