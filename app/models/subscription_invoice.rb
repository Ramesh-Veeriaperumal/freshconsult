class SubscriptionInvoice < ActiveRecord::Base

  belongs_to :subscription
  belongs_to_account

  validates :chargebee_invoice_id, :uniqueness => {:scope => :account_id} 
  # Although Chargebee Invoice ID should be unique across accounts.

  after_commit ->(obj) { obj.download_invoice }, on: :create
  after_commit ->(obj) { obj.download_invoice }, on: :update

  serialize :details

  has_one :pdf,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy

  def download_invoice
    ChargebeeInvoiceWorker.perform_async({:invoice_id => chargebee_invoice_id})
  end
end
