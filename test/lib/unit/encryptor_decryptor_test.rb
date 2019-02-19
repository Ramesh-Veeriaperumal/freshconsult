require_relative '../test_helper'
require 'minitest/spec'

class EncryptorDecryptorTest < ActiveSupport::TestCase
  PLAIN_MESSAGE = {
    message: 'Sample message'
  }.to_json

  def test_encryption_without_key
    enc_dec_obj = EncryptorDecryptor.new(nil)
    assert_raises(TypeError) do
      encrypted_message(enc_dec_obj, PLAIN_MESSAGE)
    end
  end

  def test_dencryption_without_key
    enc_dec_obj = EncryptorDecryptor.new(nil)
    assert_raises(TypeError) do
      decrypted_message(enc_dec_obj, PLAIN_MESSAGE)
    end
  end

  def test_encryption_and_decryption_with_correct_key
    msg = PLAIN_MESSAGE
    enc_dec_obj = EncryptorDecryptor.new(generate_random_key)
    encrypted_msg = encrypted_message(enc_dec_obj, msg)
    decrypted_msg = decrypted_message(enc_dec_obj, encrypted_msg)
    assert_equal decrypted_msg, msg
  end

  private

    def generate_random_key
      SecureRandom.base64(50)
    end

    def encrypted_message(object, message)
      object.encrypt(message)
    end

    def decrypted_message(object, message)
      object.decrypt(message)
    end

end
