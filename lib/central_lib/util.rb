module CentralLib
  module Util
    def encrypt_for_central(data, model_name)
      aes = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
      aes.encrypt
      aes.key = CENTRAL_SECRET_CONFIG[model_name]['key'].to_s
      aes.iv  = CENTRAL_SECRET_CONFIG[model_name]['iv'].to_s
      Base64.encode64(aes.update(data) + aes.final)
    end

    def encryption_key_name(model_name)
      CENTRAL_SECRET_CONFIG[model_name]['label']
    end
  end
end
