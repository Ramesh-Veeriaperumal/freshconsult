require_relative '../test_helper'

class ExternalActionControllerTest < ActionController::TestCase
  include ::Proactive::EmailUnsubscribeUtil

  def test_unsubscribe_email
    account = Account.first
    user = account.contacts.last
    user_data_hash, encrypted_hash = encrypted_original_message(account, user)
    post :email_unsubscribe, data: encrypted_hash
    assert_response 200
  end

  def test_unsubscribe_email_with_improper_data
    account = Account.first
    user = account.contacts.last
    user_data_hash = { user_id: user.id }
    encrypted_hash = generate_encrypted_hash(user_data_hash.to_json)
    post :email_unsubscribe, data: encrypted_hash
    assert_response 404
  end

  def test_unsubscribe_email_with_invalid_user_id
    account = Account.first
    user = account.contacts.last
    user_data_hash = { account_id: account.id, user_id: user.id + 1 }
    encrypted_hash = generate_encrypted_hash(user_data_hash.to_json)
    post :email_unsubscribe, data: encrypted_hash
    assert_response 200
  end

  def test_unsubscribe_email_with_deleted_user
    account = Account.first
    user = account.contacts.last
    user_data_hash = { account_id: account.id }
    encrypted_hash = generate_encrypted_hash(user_data_hash.to_json)
    post :email_unsubscribe, data: encrypted_hash
    assert_response 200
  end

  def test_unsubscribe_landing
    account = Account.first
    user = account.contacts.last
    user_data_hash, encrypted_hash = encrypted_original_message(account, user)
    get :unsubscribe, data: encrypted_hash
    assert_response 200
  end

  def test_unsubscribe_landing_without_data
    account = Account.first
    user = account.contacts.last
    user_data_hash, encrypted_hash = encrypted_original_message(account, user)
    get :unsubscribe
    assert_response 404
  end

  private

    def generate_encrypted_hash(value)
      encrypt_email_hash(value)
    end

    def encrypted_original_message(account, user)
      user_data_hash = {
        account_id: account.id,
        user_id: user.id
      }
      encrypted_hash = generate_encrypted_hash(user_data_hash.to_json)
      [user_data_hash, encrypted_hash]
    end
end
