class Admin::FreshcallerAccountDelegator < BaseDelegator
  validate :validate_freshcaller_account_exists?

  def initialize(record = nil, options = {})
    @freshcaller_account = record
    super(record, options)
  end

  def validate_freshcaller_account_exists?
    errors[:freshcaller_account] << :fc_account_absent if @freshcaller_account.blank?
  end
end
