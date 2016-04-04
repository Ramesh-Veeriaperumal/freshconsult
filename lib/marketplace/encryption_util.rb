class Marketplace::EncryptionUtil

  private

    def self.encrypt(data, secret)
      cipher = OpenSSL::Cipher.new('bf-ecb').encrypt
      cipher.key = secret
      binary_data = cipher.update(data.to_json.to_s) << cipher.final
      binary_data.unpack('H*').first
    end

    def self.decrypt(hex_encoded, secret)
      cipher = OpenSSL::Cipher.new('bf-ecb').decrypt
      cipher.key = secret
      binary_data = [hex_encoded].pack('H*')
      data = cipher.update(binary_data) << cipher.final
      data.force_encoding(Encoding::UTF_8)
      JSON.parse(data,:symbolize_names=>true)
    end

end
