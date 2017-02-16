module Integrations::Office365::AuthHelper

  OPEN_ID_URL = "https://substrate.office.com/sts/common/.well-known/openid-configuration"

  def verify_office_token(req, audience)
  	token = nil
      
    if (req.headers and req.headers['HTTP_AUTHORIZATION'])
      auth = req.headers['HTTP_AUTHORIZATION'].strip.split(' ')
      if (auth.length == 2 and auth[0].downcase == 'bearer')
          token = auth[1]
      end
    end
      
    if token.present?
      decoded = JWT.decode token, nil, false
      verify_options = {
          :iss => "https://substrate.office.com/sts/",
          :aud => audience,
          :verify_aud => true,
          :verify_iss => true,
          :algorithm => "RS256"
      }
      
      
      begin
        retries ||= 0
        key = openIdMetadata.getKey(decoded[1]["kid"], OPEN_ID_URL)
        raise "no key found" unless key.present?
          begin
            rsa_public = OpenSSL::PKey::RSA.new(key)
            decoded = JWT.decode(token, rsa_public, true, verify_options)

            if decoded[0]["appid"] != "48af08dc-f6d2-435f-b2a7-069abd99c086" and decoded[0]["sender"] != "outlook@freshdesk.com"
             return {:status => 400}
            end

          rescue Exception => e
            return {:status => 400}
          end
          return { :status => 200, :email_id => decoded[0]["sub"] }
      rescue
        kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::MICROSOFT_OFFICE365_KEYS))
        kv_store.group = :integration
        kv_store.remove_key
        retry if (retries += 1) <= 1
      end
    end
    return {:status => 400}
  end

  def openIdMetadata
    @openIdMetadata ||= Integrations::Office365::OpenIdMetadata.new
  end

end