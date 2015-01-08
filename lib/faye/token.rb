module Faye
  module Token

    def generate_hmac_token(user)
      digest = OpenSSL::Digest.new('sha512');
      time = (Time.now.to_i / (24 * 60 * 60)).to_i
      data = "#{user.id}|| && ||#{user.account.full_domain}#{time}"
      OpenSSL::HMAC.hexdigest(digest, NodeConfig["auto_refresh_secret"], data);
    end

  end
end
