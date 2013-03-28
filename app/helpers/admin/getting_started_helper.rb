module Admin::GettingStartedHelper

def get_logo
  unless @account.main_portal.logo.blank?
    return @account.main_portal.logo.content.url(:logo)
  end
  return "/images/logo.png?722013"
end

end