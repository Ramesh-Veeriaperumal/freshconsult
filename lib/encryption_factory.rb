class EncryptionFactory
  # Returns HEX data after encryption
  # Can be initialized with all possible encryptions supported by Openssl

  def initialize(type: 'bf-ecb', cipher_key: nil)
    @cipher = OpenSSL::Cipher::Cipher.new(type)
    @cipher_key = cipher_key || CustomSurveyResultKey::CONFIG + Account.current.id.to_s
  rescue StandardError => e
    Rails.logger.error("Error while Initialzing class :: #{e.message}")
    NewRelic::Agent.notice_error(e)
  end

  def encrypt(data)
    cipher = @cipher.encrypt
    @cipher.key = Digest::SHA256.digest(@cipher_key)
    binary_data = cipher.update(data) << cipher.final
    binary_data.unpack('H*').first
  rescue StandardError => e
    Rails.logger.error("Error while Encrypting :: #{e.message}")
    NewRelic::Agent.notice_error(e)
  end

  def decrypt(data)
    cipher = @cipher.decrypt
    @cipher.key = Digest::SHA256.digest(@cipher_key)
    binary_data = [data].pack('H*')
    decrypted_data = cipher.update(binary_data) << cipher.final
    decrypted_data.force_encoding(Encoding::UTF_8)
    decrypted_data.is_a?(TrueClass) ? nil : decrypted_data
  rescue StandardError => e
    Rails.logger.error("Error while Decrypting :: #{e.message}")
    NewRelic::Agent.notice_error(e)
  end
end
