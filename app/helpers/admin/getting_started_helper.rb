module Admin::GettingStartedHelper

def get_logo
  unless @account.main_portal.logo.blank? || @account.main_portal.logo.content.blank?
    return @account.main_portal.logo.content.url(:logo)
  end
  return "/images/gs/upload-logo.png"
end

end