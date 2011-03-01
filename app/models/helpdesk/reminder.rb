class Helpdesk::Reminder < ActiveRecord::Base
  set_table_name "helpdesk_reminders"

  belongs_to :user,
    :class_name => 'User'

  belongs_to :ticket,
    :class_name => 'Helpdesk::Ticket'

  named_scope :visible, :conditions => ["deleted = ? OR updated_at > ?", false, 1.day.ago], :order => 'deleted ASC, updated_at DESC, created_at DESC' 

  attr_accessible :body,:deleted
  
  validates_numericality_of :user_id
  validates_length_of :body, :in => 1..120

end
