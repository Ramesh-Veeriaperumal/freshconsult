class Helpdesk::Reminder < ActiveRecord::Base
  self.table_name =  "helpdesk_reminders"
  self.primary_key = :id

  belongs_to_account
  belongs_to :user,
    :class_name => 'User'

  belongs_to :ticket,
    :class_name => 'Helpdesk::Ticket'

  scope :visible, :conditions => [ "deleted = ?", false ], :order => 'updated_at ASC, created_at ASC'
  scope :logged, :conditions => [ "deleted = ? AND updated_at > ?", true, 1.day.ago ], :order => 'deleted ASC, updated_at DESC, created_at DESC' 

  attr_accessible :body,:deleted
  
  validates_numericality_of :user_id
  validates_length_of :body, :in => 1..120

  before_create :set_account_id

  private
    def set_account_id
      self.account_id = user.account_id
    end
      

end
