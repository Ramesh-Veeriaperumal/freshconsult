class AddTemplateForEmailVerification < ActiveRecord::Migration
  shard :none
  def self.up
    execute(%(INSERT INTO email_notifications (account_id, requester_notification, 
      requester_template, agent_notification, created_at, updated_at, notification_type, 
      requester_subject_template, version) select id, true, 
      "<p>Hi {{contact.name}},<br/><br/>This email address ({{email}}) has been added to your 
      {{helpdesk_name}} account. Please click on the link below to verify it.
      <br/><br/>Verification link: {{activation_url}}<br/><br/>If the link above does not work, 
      try copy-pasting the URL into your browser. Please get in touch with us if you need any help. 
      <br/><br/>Thanks, <br/>{{helpdesk_name}} <br/></p>", false, now(), now(), 17, 
      "{{helpdesk_name}} Email Activation", 2 FROM accounts))
  end

  def self.down
  	execute('DELETE FROM email_notifications where notification_type = 17')
  end
end
