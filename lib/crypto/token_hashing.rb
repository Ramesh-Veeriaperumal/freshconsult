module Crypto::TokenHashing
  DIGEST_KEY = '%{pass_key}::%{account_id}::%{token}'.freeze
  KEY_TYPE_MAPPING = {
    1 => 'generate_rts_key'
  }.freeze

  def mask_id(secret_value, key_type = 1)
    perform_hashing(secret_value, key_type)
  end

  private

    def perform_hashing(key_name, key_type)
      formatted_secret_value = safe_send(KEY_TYPE_MAPPING[key_type], key_name)
      Digest::MD5.hexdigest(formatted_secret_value)
    end

    def generate_rts_key(channel_id)
      format(DIGEST_KEY, pass_key: RTSConfig['channel_cipher_key'], account_id: Account.current.id, token: channel_id)
    end
end
