class BaseBitmapFeature
  def on_revoke_feature
    #  can be overriden by the feature class on revoking feature
  end

  def on_add_feature
    #  can be overriden by the feature class on adding feature
  end
end
