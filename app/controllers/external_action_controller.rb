class ExternalActionController < ApplicationController
  skip_before_filter  :check_privilege, :verify_authenticity_token,
                      :redactor_form_builder, :set_time_zone,
                      :check_day_pass_usage, :set_locale
  before_filter :valid_params

  include ::Proactive::EmailUnsubscribeUtil
  include ::Proactive::Constants

  layout false

  def unsubscribe
    @data = URI.unescape(params[:data])
  end

  def email_unsubscribe
    contact_hash = JSON.parse(decrypt_email_hash(URI.unescape(params[:data])))
    contact_hash.symbolize_keys!
    @unsubscribe_status = unsubscribe_user(contact_hash[:account_id], contact_hash[:user_id])
    if @unsubscribe_status
      render :unsubscribe
    else
      render_404
    end
  end

  private

    def valid_params
      render_404 unless params[:data].present?
    end
end