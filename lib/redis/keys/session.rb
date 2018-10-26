module Redis::Keys::Session
  JWT_API_JTI = "JWT:%{account_id}:%{user_id}:%{jti}".freeze
end