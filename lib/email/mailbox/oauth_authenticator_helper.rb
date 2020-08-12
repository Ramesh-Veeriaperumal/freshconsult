# frozen_string_literal: true

module Email::Mailbox::OauthAuthenticatorHelper
  include Email::Mailbox::Constants
  OAUTH_KEYS = %w[refresh_token oauth_token].freeze
  LANDING_PATH = '/a/admin/email/mailboxes'

  def build_url(params, status, reference_key)
    url_params_arr = status == OAUTH_FAILED && params['type'] != 'new' ? [] : ["reference_key=#{reference_key}"]
    params.except(*OAUTH_KEYS).each_pair { |name, val| url_params_arr << "#{name}=#{CGI.escape(val)}" }
    url_params_arr.join('&')
  end

  # this is the final redirection to ember.
  def get_redirect_url(url_params_string, redis_params, origin_account)
    protocol = Rails.env.development? ? 'http' : 'https'
    port = Rails.env.development? ? ':4200' : ''
    landing_path = if redis_params['type'] == 'new'
                     LANDING_PATH + '/new'
                   else
                     LANDING_PATH + "/#{redis_params['id']}/edit"
                   end
    redirect_domain = "#{protocol}://#{origin_account.full_domain}#{port}#{landing_path}?#{url_params_string}"
  end
end
