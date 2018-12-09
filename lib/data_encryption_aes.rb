class DataEncryptionAES
  FIXED_IV_LENGTH = 16

  attr_accessor :aes, :key, :iv, :content

  def initialize(encoded_key, algorithm)
    validate!(encoded_key, algorithm)
    @aes = OpenSSL::Cipher.new(algorithm)
    @key = DataEncryptionAES.decode_base64(encoded_key)
  end

  def encrypt_data message
    @content = message
    @iv = @aes.random_iv
    aes.encrypt
    DataEncryptionAES.encode_base64 generate_full_message(handle_cipher)
  end

  def decrypt_data encoded_message
    split_message DataEncryptionAES.decode_base64(encoded_message)
    aes.decrypt
    handle_cipher
  end

  class << self
    def encode_base64 message
      [message].pack('m')
    end

    def decode_base64 message
      message.unpack('m')[0]
    end
  end

  private
  def generate_full_message cipher
    iv + cipher
  end

  def split_message full_message
    @iv = full_message.first(FIXED_IV_LENGTH)
    @content = full_message.last(-FIXED_IV_LENGTH)
  end

  def handle_cipher
    aes.key = key
    aes.iv = iv
    aes.update(content) + aes.final
  rescue OpenSSL::Cipher::CipherError => e
    Rails.logger.error "Could not encrypt/decrypt :: Invalid key/IV"
    nil
  rescue Exception => ex
    Rails.logger.error "Could not encrypt/decrypt, exception=#{ex.inspect}, backtrace=#{ex.backtrace}"
  end

  def validate! encoded_key, algorithm
    raise ArgumentError.new("Encryption Key must be present") if encoded_key.blank?
    raise ArgumentError.new("Encryption Algorithm must be present") if algorithm.blank?
  end
end