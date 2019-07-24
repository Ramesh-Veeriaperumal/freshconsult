module EmailConfigsHelper
  def create_email_config(options = {})
    email = options[:email] || "#{Faker::Internet.domain_word}#{rand(0..9999)}@#{@account.full_domain}" 
    name = options[:name] || Faker::Name.name
    test_email_config = FactoryGirl.build(:email_config, to_email: email, reply_email: email,
                                                         primary_role: options[:primary_role] || 'true', name: name,
                                                         account_id: @account.id, active: options[:active] || 'true',
                                                         product_id: options[:product_id], group_id: options[:group_id])
    test_email_config.save(validate: false)
    test_email_config
  end
end
