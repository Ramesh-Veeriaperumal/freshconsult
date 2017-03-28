module JwtTestHelper

  def generate_jwt_token(user_id, account_id, jti, iat, algorithm = 'HS256')
    payload = {:jti => jti, :iat => iat,
               :user_id => user_id, :account_id => account_id}
    single_access_token = @account.users.find_by_id(payload[:user_id]).single_access_token
    JWT.encode payload, single_access_token, algorithm
  end

end