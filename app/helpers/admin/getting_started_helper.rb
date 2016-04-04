module Admin::GettingStartedHelper

def get_logo
  unless @account.main_portal.logo.blank?
    return @account.main_portal.logo.content.url(:logo)
  end
  return "/assets/misc/logo.png?722015"
end

end