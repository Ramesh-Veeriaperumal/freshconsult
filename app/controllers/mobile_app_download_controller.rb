class MobileAppDownloadController < ApplicationController
  def index
    @mobile_params = {
        url: current_account.full_url,
        full_domain: current_account.full_domain
    }
    render layout: false
  end
end
