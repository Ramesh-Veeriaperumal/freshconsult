module AccountOverrider
  def account
  	Rails.logger.info ":::::: Inside AccountOverrider ::::::"
    ::Account.current || super
  end
end
