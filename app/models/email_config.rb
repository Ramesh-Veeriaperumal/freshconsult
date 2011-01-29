class EmailConfig < ActiveRecord::Base
  belongs_to :account
  belongs_to :group #?!?!?! Not a literal belonging in true ER sense.
  
  validates_presence_of :to_email, :reply_email
  validates_uniqueness_of :to_email, :scope => :account_id

end
