class Account::ProxyFeature::Feature
  attr_accessor :name, :account, :created_at, :updated_at

  def initialize(name, account)
    @name = name.to_sym
    @account = account
    @created_at = Time.zone.now
    @updated_at = Time.zone.now
  end

  def to_sym
    @name
  end

  def build
    if @account.db_to_lp?(@name)
      @account.launch(feature_name)
    else
      @account.set_feature(feature_name)
    end
  end

  def create
    if @account.db_to_lp?(@name)
      @account.launch(feature_name)
    elsif Account.current.present? # to handle signups
      @account.add_feature(feature_name)
    else
      @account.set_feature(feature_name)
    end
  end

  def destroy
    if @account.db_to_lp?(@name)
      @account.rollback(feature_name)
    else
      @account.revoke_feature(feature_name)
    end
  end

  def account_id
    @account.id
  end

  alias_method :save, :create
  alias_method :save!, :save
  alias_method :delete, :destroy

  private

    def feature_name
      @account.bitmap_feature_name(@name)
    end
end
