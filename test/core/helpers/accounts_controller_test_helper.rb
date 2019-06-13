module AccountsControllerTestHelper


  def email_signup_params(params={})
    @request.env['CONTENT_TYPE'] = 'application/json'
    @request.env["HTTP_ACCEPT"] = 'application/json'
    {
        :user  => {
                    :email =>   params[:email],
                  },
        :force => params[:force]
    }
  end

  def assert_account_created_with_given_email(email)
    assert_equal(email, Account.current.admin_email)
  end

  def assert_account_created_with_feature(feature)
    assert Account.current.has_feature?(feature)
  end


end
