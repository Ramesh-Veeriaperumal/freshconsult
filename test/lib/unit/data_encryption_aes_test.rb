require_relative '../test_helper'
require 'minitest/spec'

class DataEncryptionAESTest < ActiveSupport::TestCase
  ENCRYPTION_ALGORITHM = 'AES-256-CBC'
  TEST_PLAIN_TEXT = 'AES-256-Encryption'

  def test_encryption_without_key
    assert_raises(ArgumentError) do
      DataEncryptionAES.new(nil, ENCRYPTION_ALGORITHM)
    end
  end

  def test_encryption_without_algorithm
    assert_raises(ArgumentError) do
      DataEncryptionAES.new(generate_random_key, nil)
    end
  end

  def test_encryption_and_decryption_with_correct_key
    message = TEST_PLAIN_TEXT
    key = generate_random_key
    aes_object_1 = DataEncryptionAES.new(key, ENCRYPTION_ALGORITHM)
    encrypted_text = aes_object_1.encrypt_data(message)
    aes_object_2 = DataEncryptionAES.new(key, ENCRYPTION_ALGORITHM)
    decrypted_text = aes_object_2.decrypt_data(encrypted_text)
    assert_equal decrypted_text, message
  end

  def test_encryption_and_decryption_with_incorrect_key
    message = TEST_PLAIN_TEXT
    key_1 = generate_random_key
    aes_object_1 = DataEncryptionAES.new(key_1, ENCRYPTION_ALGORITHM)
    encrypted_text = aes_object_1.encrypt_data(message)
    key_2 = generate_random_key
    aes_object_2 = DataEncryptionAES.new(key_2, ENCRYPTION_ALGORITHM)
    decrypted_text = aes_object_2.decrypt_data(encrypted_text)
    assert_equal decrypted_text, nil
  end

  private
  def generate_random_key
    SecureRandom.base64(50)
  end
end