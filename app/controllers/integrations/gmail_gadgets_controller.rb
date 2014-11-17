class Integrations::GmailGadgetsController < ApplicationController
  skip_before_filter :check_privilege, :verify_authenticity_token
  def spec
  end
end
