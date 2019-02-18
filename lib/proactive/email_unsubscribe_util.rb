module Proactive::EmailUnsubscribeUtil
  PATH = "simple_outreach_unsubscribe_status".freeze

  def cipher_key
    ProactiveServiceConfig['email_cipher_key']
  end

  def decrypt_email_hash(value)
    EncryptorDecryptor.new(cipher_key).decrypt(value)
  end

  def encrypt_email_hash(value)
    EncryptorDecryptor.new(cipher_key).encrypt(value)
  end

  def unsubscribe_user(account_id, user_id)
    opted_out_contact = Account.current.users.find_by_id(user_id)
    return true if opted_out_contact.blank? # will show unsubscribe successfull for now

    return opted_out_contact.proactive_email_outreach_unsubscribe ? true : false
  rescue StandardError => e
    Rails.logger.error("Error in unsubscribing user from proactive simple
                        email :: Account : #{account_id}, user : #{user_id}")
    NewRelic::Agent.notice_error(e, description: "Error in unsubscribing user from proactive simple
                        email :: Account : #{account_id}, user : #{user_id}")
  end

  def generate_unsubscribe_link(contact)
    data = {
      account_id: Account.current.id,
      user_id: contact.id
    }.to_json
    encrypted_data = encrypt_email_hash(data)
    encrypted_data = URI.escape(encrypted_data, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    port = Rails.env.development? ? ':3000' : ''
    protocol = Rails.env.development? ? 'http' : 'https'
    url = "#{protocol}://#{Account.current.full_domain}#{port}/#{PATH}?data=#{encrypted_data}"
  end
end