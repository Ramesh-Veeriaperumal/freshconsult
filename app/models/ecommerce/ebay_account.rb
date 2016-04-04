class Ecommerce::EbayAccount < Ecommerce::Account

  has_many :ebay_questions, :class_name => 'Ecommerce::EbayQuestion', :dependent => :nullify, :foreign_key =>'ebay_account_id'
  
  validates_uniqueness_of :external_account_id, :scope => :account_id, :message => I18n.t('admin.ecommerce.new.duplicate_account')
	before_validation :check_account_limit, :create_ebay_remote_user, :on => :create
	after_commit :unsubscribe_notifications,:remove_remote_user, on: :destroy

	def check_account_limit 
    if self.account.ebay_accounts.count >= Ecommerce::Ebay::Constants::MAX_ECOMMERCE_ACCOUNTS
      errors.add(:base,"#{I18n.t('admin.ecommerce.new.max_limit')}")
      return false  
    end
  end

  def unsubscribe_notifications
    Ecommerce::Ebay::Api.new({:site_id => self.configs[:site_id]}).make_ebay_api_call(:subscribe_to_notifications, :auth_token => self.configs[:auth_token], :enable_type => "disable")
  end

  def remove_remote_user
    ebay_reomte_user = Ecommerce::EbayRemoteUser.find_by_remote_id(self.external_account_id)
    ebay_reomte_user.destroy
  end

  def update_last_sync_time(time)
    self.last_sync_time = time
    self.save
  end

  def create_ebay_remote_user
    remote_user = Ecommerce::EbayRemoteUser.new(:remote_id => self.external_account_id, :account_id => Account.current.id)
    if remote_user.save
      true
    else
      errors.add(:base,"#{I18n.t('admin.ecommerce.new.duplicate_account')}")
      return false
    end
  end

end