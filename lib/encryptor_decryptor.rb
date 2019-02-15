class EncryptorDecryptor
  def initialize(key)
    @cipher_key = key
  end

  def cipher
    OpenSSL::Cipher::Cipher.new('aes-256-cbc')
  end

  def decrypt(value)
    decryptor = cipher.decrypt
    decryptor.key = Digest::SHA256.digest(@cipher_key)
    decryptor.update(Base64.decode64(value.to_s)) + decryptor.final
  rescue StandardError => e
    Rails.logger.error("Error while decrypting data :: #{e.message}")
    raise e
  end

  def encrypt(value)
    encryptor = cipher.encrypt
    encryptor.key = Digest::SHA256.digest(@cipher_key)
    Base64.encode64(encryptor.update(value.to_s) + encryptor.final)
  rescue StandardError => e
    Rails.logger.error("Error while encrypting data :: #{e.message}")
    raise e
  end
end
