module Aloha::Util
  include Aloha::Constants
  include Aloha::Validations

  def verify_aloha_token
    unless Rails.env.test?
      if request.headers && request.headers['HTTP_AUTHORIZATION']
        auth = request.headers['HTTP_AUTHORIZATION'].strip.split(' ')
        token = auth[1] if auth.length == 2 && auth[0].downcase == 'bearer'
      end
      decoded_token = JWT.decode token, nil, false
      kid = decoded_token[1]["kid"]
      rsa_public = get_public_key(kid)
      JWT.decode token, rsa_public, true, algorithm: 'RS256'
    end
  end

  def get_public_key(kid)
    jwks_raw = Net::HTTP.get URI AlohaConfig[:jwks_url]
    jwk = JSON.parse(jwks_raw)
    jwk = JSON::JWK.new(jwk['keys'].select { |x| x['kid'] == kid }.first)
    jwk['n'] += '=' * (4 - jwk['n'].length.modulo(4))
    jwk.to_key
  end
end
