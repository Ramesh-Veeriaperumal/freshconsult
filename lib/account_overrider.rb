module AccountOverrider
  def account
    ::Account.current || super
  end
end
