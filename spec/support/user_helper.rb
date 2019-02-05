module UsersHelper
  def add_test_agent(account=nil, options={})
    account = account || @account

    role_id = options[:role].nil? ? account.roles.find_by_name("Account Administrator").id : options[:role]

    add_agent(account, {:name => Faker::Name.name,
                        :email => Faker::Internet.email,
                        :active => 1,
                        :role => 1,
                        :agent => 1,
                        :ticket_permission => options[:ticket_permission] || Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets],
                        :role_ids => ["#{role_id}"],
                        :unique_external_id => options[:unique_external_id],
                        :agent_type => options[:agent_type] || 1})
  end

  def add_agent(account, options={})
    new_agent = FactoryGirl.build(:agent,
                                      :account_id => account.id,
                                      :available => 1,
                                      :ticket_permission => options[:ticket_permission],
                                      :agent_type => options[:agent_type] || 1)
    new_user = FactoryGirl.build(:user,
                                    :account_id => account.id,
                                    :name => options[:name],
                                    :email => options[:email],
                                    :helpdesk_agent => options[:agent],
                                    :time_zone => "Chennai",
                                    :active => options[:active],
                                    :user_role => options[:role],
                                    :delta => 1,
                                    :language => "en",
                                    :role_ids => options[:role_ids])
    if options[:unique_external_id]
      new_user.unique_external_id = options[:unique_external_id]
    end
    new_user.agent = new_agent
    new_user.privileges = options[:privileges] || account.roles.find_by_id(options[:role_ids].first).privileges
    v = new_user.save_without_session_maintenance
    if options[:group_id]
      ag_grp = AgentGroup.new(:user_id => new_agent.user_id , :account_id =>  account.id, :group_id => options[:group_id])
      ag_grp.save!
    end
    new_user.reload
  end

  def add_new_user(account, options={})

    if options[:email]
      user = User.find_by_email(options[:email])
      return user if user
    end
    tag_names = options[:tags].is_a?(Array) ? options[:tags].join(",") : options[:tags]
    new_user = FactoryGirl.build(:user, :account => account,
                                    :name => options[:name] || Faker::Name.name,
                                    :email => options[:email] || Faker::Internet.email,
                                    :time_zone => "Chennai",
                                    :delta => 1,
                                    :deleted => options[:deleted] || 0,
                                    :blocked => options[:blocked] || 0,
                                    :active => options.key?(:active) ? options[:active] : 1,
                                    :company_id => options[:customer_id] || nil,
                                    :language => "en",
                                    :tag_names => tag_names)
    if options[:unique_external_id]
      new_user.unique_external_id = options[:unique_external_id]
    end
    new_user.custom_field = options[:custom_fields] if options.key?(:custom_fields)
    new_user.avatar = options[:avatar] if options[:avatar]
    new_user.updated_at = options[:updated_at] if options[:updated_at]
    new_user.save_without_session_maintenance
    new_user.reload
  end

  def add_new_contractor(account, options={})
    new_user = FactoryGirl.build(:user, :account => account,
                                    :name => options[:name] || Faker::Name.name,
                                    :email => options[:email] || Faker::Internet.email,
                                    :time_zone => "Chennai",
                                    :delta => 1,
                                    :deleted => options[:deleted] || 0,
                                    :blocked => options[:blocked] || 0,
                                    :language => "en")
    new_user.save_without_session_maintenance
    new_user.company_ids = options[:company_ids]
    new_user.save_without_session_maintenance
    new_user.reload
  end

  def add_user_with_multiple_emails(account, number, options={})
    new_user = add_new_user(@account, options)
    new_user.helpdesk_agent = 0;
    new_user.save_without_session_maintenance
    new_user.reload
    number.times do |i|
      email = Faker::Internet.email
      new_user.user_emails.build({:email => email})
    end
    new_user.save_without_session_maintenance
    new_user.reload
  end

  def fake_a_contact
    @params = { :user=> { 
                          :name => Faker::Name.name, 
                          :email => Faker::Internet.email,
                          :time_zone => "Chennai",
                          :delta => 1, 
                          :language => "en"
                        }
              }
  end

  def add_new_user_without_email(account,options={})
    if options[:phone]
      user = User.find_by_phone(options[:phone])
      return user if user
    end
    new_user = FactoryGirl.build(:user, :account => account,
                                    :name => options[:name] || Faker::Name.name,
                                    :phone => options[:phone] || Faker::PhoneNumber.phone_number,
                                    :time_zone => "Chennai",
                                    :delta => 1,
                                    :deleted => options[:deleted] || 0,
                                    :blocked => options[:blocked] || 0,
                                    :customer_id => options[:customer_id] || nil,
                                    :language => "en")
    new_user.save_without_session_maintenance
    new_user.reload
  end

  def add_new_user_with_fb_id(account,options={})
    if options[:fb_profile_id]
      user = User.find_by_fb_profile_id(options[:fb_profile_id])
      return user if user
    end
    new_user = FactoryGirl.build(:user, :account => account,
                                    :name => options[:name] || Faker::Name.name,
                                    :fb_profile_id => options[:fb_profile_id] || Faker::Name.name,
                                    :time_zone => "Chennai",
                                    :delta => 1,
                                    :deleted => options[:deleted] || 0,
                                    :blocked => options[:blocked] || 0,
                                    :customer_id => options[:customer_id] || nil,
                                    :language => "en")
    new_user.save_without_session_maintenance
    new_user.reload
  end

  def add_new_user_with_twitter_id(account,options={})
    if options[:twitter_id]
      user = User.find_by_twitter_id(options[:twitter_id])
      return user if user
    end
    new_user = FactoryGirl.build(:user, :account => account,
                                    :name => options[:name] || Faker::Name.name,
                                    :twitter_id => options[:twitter_id] || "@#{Faker::Name.name}",
                                    :time_zone => "Chennai",
                                    :delta => 1,
                                    :deleted => options[:deleted] || 0,
                                    :blocked => options[:blocked] || 0,
                                    :customer_id => options[:customer_id] || nil,
                                    :language => "en")
    new_user.save_without_session_maintenance
    new_user.reload
  end
  
  # Helpers
  def other_user
    u = User.find { |x| @agent.can_assume?(x) } || create_dummy_customer
    u.update_column(:email, Faker::Internet.email)
    u.preferences[:agent_preferences][:undo_send] = false
    u.reload
  end

  def deleted_user
    user = User.find { |x| x.id != @agent.id } || create_dummy_customer
    user.update_column(:deleted, true)
    user.update_column(:email, Faker::Internet.email)
    user.reload
  end

  def get_default_user
    User.first_or_create do |user|
      user.name = Faker::Name.name
      user.email = Faker::Internet.email
      user.time_zone = "Chennai"
      user.delta = 1,
      user.language = "en"
    end
  end

  def user_address_params
    @address_param =  {:street => Faker::Address.street_address,
        :city => Faker::Address.city,
        :state => Faker::Address.state,
        :postal_code => Faker::Address.postcode,
        :country => 'DE'}
  end
end
