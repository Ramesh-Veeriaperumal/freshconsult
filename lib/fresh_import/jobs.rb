require 'openssl'
require 'base64'

module FreshImport::Jobs
  class FreshDesk
    def self.queue(params) 
      current_account = Account.current
      current_user = User.current
      params[:type] = "freshdesk"
      params[:name] = params[:select_session][:name]
      params[:full_domain] = Encrypt.data_string(current_account.full_domain)
      params[:account_id] = current_account.id
      params[:single_access_token] = Encrypt.data_string(current_user.single_access_token)
      params.except! :session_select
      puts "Freshdesk import session request has been sent"
      $sqs_fresh_import.send_message params
    end
  end

  class Kayako
    def self.queue(params)
      params[:type] = "kayako"
      params[:account_id] = Account.current.id
      params[:api_url] = Encrypt.data_string(params[:api_url])
      params[:api_key] = Encrypt.data_string(params[:api_key])
      params[:secret_key] = Encrypt.data_string(params[:secret_key])
      puts "Kayako session request has been sent"
      $sqs_fresh_import.send_message params
    end
  end

  class ServiceDesk
    def self.queue(params)
      params[:type] = "desk"
      params[:account_id] = Account.current.id
      params[:subdomain] = Encrypt.data_string params[:subdomain]
      params[:consumer_key] = Encrypt.data_string params[:consumer_key]
      params[:consumer_secret] = Encrypt.data_string params[:consumer_secret]
      params[:oauth_token] = Encrypt.data_string params[:oauth_token]
      params[:oauth_token_secret] = Encrypt.data_string params[:oauth_token_secret]
      params[:support_email] = Encrypt.data_string params[:support_email] unless params[:support_email].nil?
      params[:desk_pass] = Encrypt.data_string params[:desk_pass] unless params[:desk_pass].nil?
      $sqs_fresh_import.send_message params
    end
  end

  class Encrypt
    def self.data_string plain_text
      public_key =
        OpenSSL::PKey::RSA.new(File.read('lib/fresh_import/public.pem'))
      Base64.encode64(public_key.public_encrypt(plain_text))
    end
  end
end
