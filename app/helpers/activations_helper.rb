module ActivationsHelper

  def user_info(attr_name)
    email_signup_admin? ? Account.current.send("admin_#{attr_name}") : @user.send(attr_name)
  end

  def company_name
    company_name = Account.current.account_configuration.admin_company_name if (Account.current.email_signup? && @user.can_verify_account?)
    company_name ||= Account.current.name
  end

  def email_signup_admin?
    @email_signup_admin ||= (Account.current.email_signup? && (Account.current.admin_email == @user.email))
  end

end
