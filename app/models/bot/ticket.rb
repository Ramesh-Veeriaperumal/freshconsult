class Bot::Ticket < ActiveRecord::Base
  self.table_name = 'bot_tickets'

  attr_accessible :ticket_id, :bot_id, :query_id, :conversation_id

  belongs_to :ticket, class_name: 'Helpdesk::Ticket'
  belongs_to :bot, class_name: 'Helpdesk::Bot'
  belongs_to_account

  validates :account_id, presence: true
  validates :bot_id, presence: true
  validates :ticket_id, presence: true
end
