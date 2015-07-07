module EmailConfigsHelper
  def create_email_config(options = {})
    email = "#{Faker::Internet.domain_word}@#{@account.full_domain}" unless options[:email]
    test_email_config = FactoryGirl.build(:email_config, to_email: email, reply_email: email,
                                                         primary_role: 'true', name: Faker::Name.name,
                                                         account_id: @account.id, active: 'true',
                                                         product_id: options[:product_id])
    test_email_config.save(validate: false)
    test_email_config
  end
end
