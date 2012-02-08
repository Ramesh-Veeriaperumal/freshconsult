class Integrations::GmailGadgetsController < ApplicationController

  def spec
    if Rails.env.production?
      spec_file_name = "production-gadget-spec.xml"
    elsif Rails.env.staging?
      spec_file_name = "staging-gadget-spec.xml"
    elsif Rails.env.development?
      spec_file_name = "development-gadget-spec.xml"
    end
    cert_file  = "#{RAILS_ROOT}/config/google-apps/#{spec_file_name}"
    respond_to do |format|
      format.xml do
        render :xml => File.read(cert_file)
      end
    end
  end
end
