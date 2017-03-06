module Integrations::Office365
  class OpenIdMetadata

    def getKey(kid, url)
      kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::MICROSOFT_OFFICE365_KEYS))
      kv_store.group = :integration
      keys = kv_store.get_key
      keys = JSON.parse(keys) if keys.present?
      keys = refreshCache(url) if keys.blank?
      key = nil
      key = find_key(keys, kid) if keys.present?
      return key
    end

    private

      def refreshCache(url)
        uri = URI.parse(url)
        res = Net::HTTP.get_response(uri)
        if res.code.to_i >=400 or res.body.blank?
          Rails.logger.debug "Failed to load openID config: #{res.code}"
          return nil
        else
          openIdConfig = JSON.parse(res.body)
          uri2 = URI.parse(openIdConfig["jwks_uri"])
          res2 = Net::HTTP.get_response(uri2)
            if res2.code.to_i >= 400 or res2.body.blank?
              Rails.logger.debug "Failed to load openID config: #{res2.code}"
              return nil
            end
            if res2.code.to_i == 200 and res2.body.present?
              keys = JSON.parse(res2.body)["keys"]
              key_spec = Redis::KeySpec.new(Redis::RedisKeys::MICROSOFT_OFFICE365_KEYS)
              Redis::KeyValueStore.new(key_spec, keys.to_json, {:group => :integration, :expire => 1800}).set_key
              return keys
            end
            return nil
        end
      end

      def find_key(keys, key_id)
        keys.each do |key|
          if key["kid"] == key_id
            return nil if (key["n"].blank? or key["e"].blank?)
            return rsa.get_pem(key["n"], key["e"]) # modulus,exponent
          end
        end
        return nil
      end

      def rsa
        @rsa ||= Integrations::Office365::RsaPemFromModExp.new
      end

  end
end