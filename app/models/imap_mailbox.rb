class ImapMailbox < ActiveRecord::Base

  include EmailHelper
  
  self.primary_key = :id

  belongs_to :email_config

  belongs_to_account

  attr_protected :account_id

  self.primary_key = :id

  scope :errors, -> { where("error_type > ?", 0)  }


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
        :folders_list => {"standard"=>["inbox"]},
        :use_ssl => use_ssl,
        :to_email => email_config.to_email,
        :account_id => account_id,
        :time_zone => account.time_zone,
        :timeout => timeout, 
        :pod_info => pod_info,
        :domain => account.full_domain,
        :application_id => imap_application_id
      },
      :action => action
      }.to_json
  end
end