class Helpdesk::Reminder < ActiveRecord::Base
  self.table_name =  "helpdesk_reminders"
  self.primary_key = :id

  belongs_to_account
  belongs_to :user,
    :class_name => 'User'

  belongs_to :ticket,
    :class_name => 'Helpdesk::Ticket'
  belongs_to :contact, class_name: 'User', foreign_key: 'contact_id',
    inverse_of: :contact_reminders

  scope :visible, :conditions => [ "deleted = ?", false ], :order => 'updated_at ASC, created_at ASC'
  scope :logged, lambda { |time|
          { :conditions => ["deleted = ? AND updated_at > ?", true, time], :order => 'deleted ASC, updated_at DESC, created_at DESC'  }
        }

  attr_accessible :body,:deleted
  
  validates_numericality_of :user_id
  validates_presence_of :body
  validates_length_of :body, :in => 1..120

  before_create :set_account_id

  private
  
    # since reminder.user is api_current_user setting Account.current.id to avoid user query
    def set_account_id
      self.account_id = Account.current.id || user.account_id
    end
      

end
