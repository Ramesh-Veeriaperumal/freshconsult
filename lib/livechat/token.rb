module Livechat::Token
  def livechat_token(site_id, user_id)
    digest = OpenSSL::Digest::Digest.new('sha512');
    data = "#{site_id}|| && ||#{user_id}"
    OpenSSL::HMAC.hexdigest(digest, ChatConfig['secret_key'], data);
  end

  def livechat_partial_token(auth_id)
    digest = OpenSSL::Digest::Digest.new('sha512');
    data = "|| && ||#{auth_id}"
    OpenSSL::HMAC.hexdigest(digest, ChatConfig['secret_key'], data);
  end
end