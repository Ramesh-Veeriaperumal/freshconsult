class ImapMailbox < ActiveRecord::Base

  belongs_to :email_config

  belongs_to_account

  attr_protected :account_id

  def imap_params(action)
    { :mailbox_attributes => { :id => id,
        :user_name => user_name,
        :password => password,
        :server_name => server_name,
        :server_port => port,
        :authentication => authentication,
        :delete_from_server => delete_from_server,
        :folder => folder,
        :use_ssl => use_ssl,
        :to_email => email_config.to_email,
        :account_id => account_id,
        :time_zone => account.time_zone,
        :timeout => timeout
      },
      :action => action
      }.to_json
  end
end