class Account::ProxyFeature::ProxyFeatureAssociation
  attr_accessor :account

  def initialize(account)
    @account = account
  end

  def map
    @account.features_list + @account.launched_db_feature
  end

  def feature?(feature)
    feature_name = @account.bitmap_feature_name(feature)
    if @account.db_to_lp?(feature)
      @account.launched?(feature_name)
    else
      @account.has_feature?(feature_name)
    end
  end

  def build(*features)
    features.map { |feature| safe_send(feature).build }
  end

  def reload
    true
  end
end
