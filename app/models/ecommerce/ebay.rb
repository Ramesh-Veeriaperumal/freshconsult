class Ecommerce::Ebay < Ecommerce::Account

  has_many :ebay_items, :class_name => 'Ecommerce::EbayItem', :dependent => :delete_all, :foreign_key =>'ebay_acc_id'

  after_commit ->(obj) { obj.validate_account }, :on => :create
  after_commit ->(obj) { obj.validate_account }, :on => :update

  def validate_account
    Resque.enqueue(Workers::Ecommerce::Ebay::ValidateAccount, {:ecommerce_account_id => self.id})
  end

  def activate_account(id)
    self.class.where(:id => self.id, :account_id => self.account_id).update_all(:active => true, :external_account_id => id)
  end

  def deactivate_account
    self.class.where(:id => self.id, :account_id => self.account_id).update_all(:active => false, :external_account_id => nil)
  end
end