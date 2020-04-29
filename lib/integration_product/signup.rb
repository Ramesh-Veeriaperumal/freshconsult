module IntegrationProduct::Signup
  def signup_via_aloha(product_name)
    response = HTTParty.post("#{AlohaConfig[:host]}v2/signup/#{product_name}?source=omnibar", body: signup_body.to_json, headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' })
    Rails.logger.info "Freshchat Response :: #{response.code} #{response.message} #{response.headers.inspect}"
    response
  end

  private

    def signup_body
      account = Account.current
      {
        user: user_params,
        organisation: Freshid::V2::Models::Organisation.find_by_domain(account.organisation.domain).except!(:create_time, :update_time),
        session_json: account.conversion_metric.session_json,
        currency: account.currency_name,
        first_referrer: account.conversion_metric.first_referrer,
        first_landing_page: account.conversion_metric.first_landing_url,
        join_token: Freshid::V2::Models::Organisation.join_token,
        misc: {
          account_domain: account.domain,
          preferredDomain: account.domain
        }
      }
    end

    def user_params
      freshid_user = Freshid::V2::Models::User.find_by_email(User.current.email)
      {
        id: freshid_user.id,
        first_name: freshid_user.first_name,
        middle_name: freshid_user.middle_name,
        last_name: freshid_user.last_name,
        email: freshid_user.email,
        phone: freshid_user.phone,
        mobile: freshid_user.mobile,
        job_title: freshid_user.job_title,
        company_name: freshid_user.company_name
      }
    end
end
