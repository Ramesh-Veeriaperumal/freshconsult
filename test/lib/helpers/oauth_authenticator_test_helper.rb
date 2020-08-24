# frozen_string_literal: true

module OauthAuthenticatorTestHelper
  def options(app = 'gmail', failed = false, r_key = nil)
    {
      app: app,
      user_id: 1,
      r_key: r_key,
      failed: failed,
      origin_account: @account
    }
  end

  def params(type = 'new')
    {
      type: type
    }
  end

  def cached_obj(type = 'new')
    {
      'type' => type,
      'r_key' => 'test@1234'
    }
  end

  def omniauth_for_outlook
    {
      credentials: OpenStruct.new(
        refresh_token: 'testrefreshtoken',
        token: 'testtoken'
      ),
      'extra' => {
        'raw_info' => {
          'EmailAddress' => 'testemail'
        }
      }
    }
  end

  def omniauth_for_gmail
    {
      credentials: OpenStruct.new(
        refresh_token: 'testrefreshtoken',
        token: 'testtoken'
      ),
      'info' => {
        'email' => 'testemail'
      }
    }
  end
end
