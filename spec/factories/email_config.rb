if Rails.env.test?
  FactoryGirl.define do
    factory :email_config, :class => EmailConfig do
      sequence(:name) { |n| "EmailConfig#{n}" }
      primary_role false
    end

    factory :primary_email_config, :class => EmailConfig do
      sequence(:name) { |n| "PrimaryEmailConfig#{n}" }
      primary_role true
    end

    factory :imap_mailbox, :class => ImapMailbox do
      server_name "imap.gmail.com"
      user_name Faker::Internet.email
      password Faker::Lorem.characters(100)
      port 993
      authentication "plain"
      use_ssl true
      folder "inbox"
      delete_from_server false
      timeout 1500
    end

    factory :smtp_mailbox, :class => SmtpMailbox do
      server_name "smtp.gmail.com"
      user_name Faker::Internet.email
      password Faker::Lorem.characters(100)
      port 587
      authentication "plain"
      use_ssl true
      domain Faker::Internet.domain_name
    end
  end
end