class ImapMailbox < ActiveRecord::Base

  self.primary_key = :id

  belongs_to :email_config

  belongs_to_account

  attr_protected :account_id

  self.primary_key = :id

  def selected_server_profile
    selected_profile = MailboxConstants::MAILBOX_SERVER_PROFILES.select {|server| server_name && server_name.casecmp("imap.#{server[4]}") == 0}
    selected_profile.first.nil? ?  "other" : selected_profile.first[0].to_s
  end

  def imap_params(action)
    shard = ShardMapping.lookup_with_account_id(account_id)
    pod_info = shard.present? ? shard.pod_info : PodConfig['CURRENT_POD']

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
        :timeout => timeout, 
        :pod_info => pod_info,
        :domain => account.full_domain
      },
      :action => action
      }.to_json
  end
end