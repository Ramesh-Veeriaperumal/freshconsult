require 'test_helper'

SE = ValidatesCaptcha::SymmetricEncryptor::Simple

class SymmetricEncryptorTest < ValidatesCaptcha::TestCase
  test "defines a class level #secret method" do
    assert_respond_to SE, :secret
  end

  test "defines an instance level #secret method" do
    assert_respond_to SE.new, :secret
  end

  test "defines a class level #secret= method" do
    assert_respond_to SE, :secret=
  end

  test "#secret method's return value should equal the value set using the #secret= method" do
    old_secret = SE.secret

    SE.secret = 'abc'
    assert_equal 'abc', SE.secret

    SE.secret = old_secret
  end

  test "defines an instance level #encrypt method" do
    assert_respond_to SE.new, :encrypt
  end

  test "instance level #encrypt method returns a string" do
    assert_kind_of String, SE.new.encrypt('abc')
  end

  test "defines an instance level #decrypt method" do
    assert_respond_to SE.new, :decrypt
  end

  test "instance level #decrypt method returns nil if decryption failes" do
    assert_nil SE.new.decrypt('invalid')
  end

  test "decryption of encryption of string should equal the string" do
    %w(d3crypti0n 3ncrypt3d 5trin9 sh0u1d equ41 th3 c4ptch4).each do |captcha|
      assert_equal captcha, SE.new.decrypt(SE.new.encrypt(captcha))
    end
  end
end

