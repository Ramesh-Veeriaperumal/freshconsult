module Helpdesk::EncryptedField

  def encrypt_field_value(value)
    aes_encryption = aes_cipher_object
    aes_encryption.present? && valid_value?(value) ? aes_encryption.encrypt_data(value) : nil
  end

  def decrypt_field_value(value)
    aes_decryption = aes_cipher_object
    aes_decryption.present? && valid_value?(value) ? aes_decryption.decrypt_data(value) : nil
  end

  private
  def aes_cipher_object
    hipaa_encryption_key = Account.current.hipaa_encryption_key
    DataEncryptionAES.new(hipaa_encryption_key, AccountConstants::HIPAA_ENCRYPTION_ALGORITHM) if hipaa_encryption_key.present?
  end

  def valid_value? value
    value.present? && Account.current.hipaa_and_encrypted_fields_enabled?
  end
end