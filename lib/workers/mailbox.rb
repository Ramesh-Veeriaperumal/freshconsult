class Workers::Mailbox
  extend Resque::AroundPerform
  @queue = "mailbox_queue"
  
  def self.perform(args)
    account = Account.current
    if args[:action] == "delete"
      delete_mailbox_thread args[:mailbox_id]
    else
      mailbox = account.mailboxes.find(args[:mailbox_id])
      send("#{args[:action]}_mailbox_thread", mailbox) if mailbox
    end
  end

  def self.create_mailbox_thread mailbox
    request_post = Net::HTTP::Post.new("/imap_mailboxes", initheader = {'Content-Type' =>'application/json'})
    timestamp = Time.now.to_i
    request_post.body = mailbox.imap_params(timestamp)
    request_post.basic_auth "freshdesk", password_hash(timestamp)
    request = Rails.env.development? ? Net::HTTP.new("localhost", "3001") : Net::HTTP.new("mailbox.#{AppConfig['base_domain'][Rails.env]}")
    response = request.start {|http| http.request(request_post) }
    puts "Creation of #{mailbox.imap_user_name} - response - #{response.code} #{response.message}: #{response.body}"
  end

  def self.delete_mailbox_thread mailbox_id
    request_delete = Net::HTTP::Delete.new("/imap_mailboxes/#{mailbox_id}", initheader = {'Content-Type' =>'application/json'})    
    timestamp = Time.now.to_i
    request_delete.body = {"timestamp" => timestamp, "imap_mailboxes" => { "account_id" => Account.current.id }}.to_json
    request_delete.basic_auth "freshdesk", password_hash(timestamp)
    request = Rails.env.development? ? Net::HTTP.new("localhost", "3001") : Net::HTTP.new("mailbox.#{AppConfig['base_domain'][Rails.env]}")
    response = request.start {|http| http.request(request_delete) }    
    puts "Deletion of #{mailbox_id} - response -  #{response.code} #{response.message}: #{response.body}"
  end

  def self.update_mailbox_thread mailbox
    request_put = Net::HTTP::Put.new("/imap_mailboxes/#{mailbox.id}", initheader = {'Content-Type' =>'application/json'})
    timestamp = Time.now.to_i
    request_put.body = mailbox.imap_params(timestamp)
    request_put.basic_auth "freshdesk", password_hash(timestamp)
    request = Rails.env.development? ? Net::HTTP.new("localhost", "3001") : Net::HTTP.new("mailbox.#{AppConfig['base_domain'][Rails.env]}")
    response = request.start {|http| http.request(request_put) }
    puts "Updation of #{mailbox.imap_user_name} - response -  #{response.code} #{response.message}: #{response.body}"
  end

  def self.password_hash(timestamp)
    digest  = OpenSSL::Digest::Digest.new('MD5')
    OpenSSL::HMAC.hexdigest(digest, MailboxConfig["secret_key"], "freshdesk"+timestamp.to_s)
  end
end