class Ecommerce::EbayQuestion < ActiveRecord::Base

  self.table_name = :ebay_questions
  belongs_to_account
  belongs_to :ebay_account, :class_name =>'Ecommerce::EbayAccount', :foreign_key =>'ebay_account_id'
  belongs_to :questionable, :polymorphic => true
  belongs_to :user, :class_name => "::User"


  validates :user_id, :questionable_id, :ebay_account_id, :presence => true
  validates :message_id, :uniqueness => { :scope => :account_id }, :allow_nil => true 

  scope :fetch_with_item_id_user_id, lambda{ |item_id, user_id| where("item_id = ? and user_id = ? and questionable_type = ?", item_id, user_id, 'Helpdesk::Ticket') }

  scope :fetch_with_user_id, lambda{|user_id| where("user_id = ? and questionable_type = ?", user_id, 'Helpdesk::Ticket' ) }

end