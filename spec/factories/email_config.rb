if Rails.env.test?
  Factory.define :email_config, :class => EmailConfig do |e|
    e.sequence(:name) { |n| "EmailConfig#{n}" }
    e.primary_role false
  end

  Factory.define :primary_email_config, :class => EmailConfig do |p|
    p.sequence(:name) { |n| "PrimaryEmailConfig#{n}" }
    p.primary_role true
  end

  Factory.define :imap_mailbox, :class => ImapMailbox do |m|
    m.server_name "imap.gmail.com"
    m.user_name Faker::Internet.email
    m.password Faker::Lorem.characters(100)
    m.port 993
    m.authentication "plain"
    m.use_ssl true
    m.folder "inbox"
    m.delete_from_server false
    m.timeout 1500
  end

  Factory.define :smtp_mailbox, :class => SmtpMailbox do |m|
    m.server_name "smtp.gmail.com"
    m.user_name Faker::Internet.email
    m.password Faker::Lorem.characters(100)
    m.port 587
    m.authentication "plain"
    m.use_ssl true
    m.domain Faker::Internet.domain_name
  end
end