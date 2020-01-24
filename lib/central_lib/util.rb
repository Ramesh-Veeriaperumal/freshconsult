module CentralLib
  module Util
    def encrypt_for_central(data, model_name)
      return nil if data.blank?

      aes = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
      aes.encrypt
      aes.key = CENTRAL_SECRET_CONFIG[model_name]['key'].to_s
      aes.iv  = CENTRAL_SECRET_CONFIG[model_name]['iv'].to_s
      Base64.encode64(aes.update(data) + aes.final)
    end

    def encryption_key_name(model_name)
      CENTRAL_SECRET_CONFIG[model_name]['label']
    end

    def attribute_changes(column_name = nil)
      attributes_was, attributes_is = column_name ? [@old_model[column_name.to_s], attributes[column_name.to_s]] : [@old_model, attributes]
      change_hash = {}
      if attributes_was != attributes_is
        new_hash = attributes_was.merge(attributes_is)
        new_hash.keys.each do |key|
          change_hash[key] = [attributes_was[key], attributes_is[key]] if attributes_was[key] != attributes_is[key]
        end
      end
      change_hash
    end
  end
end
