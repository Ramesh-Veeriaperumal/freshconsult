class LaunchPartyFeature
  attr_accessor :feature_name
  def on_launch(args = nil)
    # This is a stub, same method can be overridden when writing callback on launching the feature
  end

  def on_rollback(args = nil)
    # This is a stub, same method can be overridden when writing callback on rollback the feature
  end
end