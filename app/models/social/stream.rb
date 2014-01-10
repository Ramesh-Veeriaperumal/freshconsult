class Social::Stream < ActiveRecord::Base

  set_table_name "social_streams"
  belongs_to_account

  serialize :data, Hash
  serialize :includes, Array
  serialize :excludes, Array

  validates_presence_of :account_id
  
  has_many :ticket_rules, 
    :class_name => 'Social::TicketRule',
    :foreign_key => :stream_id,
    :dependent => :destroy # Must delete the ticket rule if stream is deleted

end
