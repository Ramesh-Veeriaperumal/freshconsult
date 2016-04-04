class Mobihelp::Device < ActiveRecord::Base
  self.primary_key = :id
  self.table_name =  :mobihelp_devices

  belongs_to_account

  attr_protected :account_id

  has_many :ticket_extras, :class_name =>'Mobihelp::TicketInfo'
  has_many :tickets, :through => :ticket_extras, :class_name => 'Helpdesk::Ticket'
  belongs_to :app, :class_name => 'Mobihelp::App'
end
