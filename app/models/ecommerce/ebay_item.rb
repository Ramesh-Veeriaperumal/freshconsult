class Ecommerce::EbayItem < ActiveRecord::Base

	self.table_name = :ebay_items
	attr_protected :account_id
	belongs_to_account
  belongs_to :ebay_account, :class_name =>'Ecommerce::Ebay', :foreign_key =>'ebay_acc_id'
	belongs_to :ticket, :class_name => 'Helpdesk::Ticket'


	validates :message_id, :ticket_id, :ebay_acc_id, :presence => true

  scope :fetch_with_item_id_user_id, lambda{ |item_id, user_id| where("item_id = ? and user_id = ?", item_id, user_id ) }

  scope :fetch_with_user_id, lambda{|user_id| where("user_id = ?", user_id) }

end