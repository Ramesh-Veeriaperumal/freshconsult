['contact_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

module ModelsUsersTestHelper
  include ContactFieldsTestHelper

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
                        :agent_type => options[:agent_type] || 1 })
  end

  def add_agent(account, options={})
    acc_subscription = Account.current.subscription
    old_subscription_state = acc_subscription.state
    acc_subscription.state = 'trial'
    acc_subscription.save
    role_id = @account.roles.find_by_name("Agent").id
    new_agent = FactoryGirl.build(:agent,
                                  :account_id => account.id,
                                  :available => options[:available] || 1,
                                  :ticket_permission => options[:ticket_permission] || Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets],
                                  :agent_type => options[:agent_type] || 1)
    new_user = FactoryGirl.build(:user,
                                    :account_id => account.id,
                                    :name => options[:name] || Faker::Name.name,
                                    :email => options[:email] || Faker::Internet.email,
                                    :helpdesk_agent => options[:agent] || 1,
                                    :time_zone => options[:time_zone] || "Chennai",
                                    :active => options[:active] || 1,
                                    :user_role => options[:role] || role_id,
                                    :delta => 1,
                                    :language => "en",
                                    :role_ids => options[:role_ids] || ["#{role_id}"])
    new_user.agent = new_agent
    new_user.privileges = options[:privileges] || account.roles.find_by_id(role_id).privileges
    v = new_user.save_without_session_maintenance
    if options[:group_id]
      ag_grp = AgentGroup.new(:user_id => new_agent.user_id , :account_id =>  account.id, :group_id => options[:group_id])
      ag_grp.save!
    end
    new_user.reload
  ensure
    acc_subscription.state = old_subscription_state
    acc_subscription.save
  end

  def build_tags(tag_names)
    tags = []
    existing_tags = Helpdesk::Tag.where(account_id: @account.id)
    tag_names_taken = existing_tags.map(&:name)
    tag_names -= tag_names_taken if tag_names.present?
    tag_names.each do |tag_name|
      tags << Helpdesk::Tag.new(name: tag_name)
    end
    [*tags, *existing_tags]
  end

  def add_new_user(account, options={})
    begin
      if options[:email]
        user = User.find_by_email(options[:email])
        return user if user
      end
      new_user = FactoryGirl.build(:user,
                                    account: account,
                                    name: options[:name] || Faker::Name.name,
                                    email: options[:email] || Faker::Internet.email,
                                    time_zone: options[:time_zone] || 'Chennai',
                                    delta: 1,
                                    deleted: options[:deleted] || 0,
                                    blocked: options[:blocked] || 0,
                                    company_id: options[:customer_id] || nil,
                                    language: options[:language] || 'en',
                                    active: options[:active] || false,
                                    tags: build_tags(options[:tags]))
      new_user.custom_field = options[:custom_fields] if options.key?(:custom_fields)
      new_user.save_without_session_maintenance
      new_user.reload
    rescue ActiveRecord::RecordNotFound
      p "ActiveRecord::RecordNotFound on new_user.reload"
      p new_user.inspect
      new_user
    end
  end

  def update_user
    user = Account.current.technicians.first
    user.name = Faker::Name.name
    user.save_without_session_maintenance
  end
  
  def central_publish_user_pattern(user)
    pattern = {
      id: user.id,
      name: user.name,
      type: user.helpdesk_agent ? 'agent' : 'contact',
      email: user.email,
      last_login_ip: user.last_login_ip,
      current_login_ip: user.current_login_ip,
      login_count: user.login_count,
      failed_login_count: user.failed_login_count,
      account_id: user.account_id,
      active: user.active,
      customer_id: user.customer_id,
      job_title: user.job_title,
      second_email: user.second_email,
      phone: user.phone,
      mobile: user.mobile,
      twitter_id: user.twitter_id,
      description: user.description,
      time_zone: user.time_zone,
      posts_count: user.posts_count,
      deleted: user.deleted,
      user_role: user.user_role,
      delta: user.delta,
      import_id: user.import_id,
      fb_profile_id: user.fb_profile_id,
      language: user.language,
      blocked: user.blocked,
      address: user.address,
      whitelisted: user.whitelisted,
      external_id: user.external_id,
      preferences: user.preferences,
      helpdesk_agent: user.helpdesk_agent,
      privileges: user.privileges,
      extn: user.extn,
      parent_id: user.parent_id,
      company_id: user.company_id,
      unique_external_id: user.unique_external_id,
      last_login_at: user.last_login_at.try(:utc).try(:iso8601), 
      current_login_at: user.current_login_at.try(:utc).try(:iso8601), 
      last_seen_at: user.last_seen_at.try(:utc).try(:iso8601), 
      tags: user.tags.collect { |tag| { id: tag.id, name: tag.name } },
      other_emails: user.user_emails.where(primary_role: false).pluck(:email),
      other_company_ids: user.user_companies.where(default: false).pluck(:company_id),
      blocked_at: user.blocked_at.try(:utc).try(:iso8601), 
      deleted_at: user.deleted_at.try(:utc).try(:iso8601), 
      created_at: user.created_at.try(:utc).try(:iso8601), 
      updated_at: user.updated_at.try(:utc).try(:iso8601),
    }
    pattern[:custom_fields] = user.custom_field_hash('contact') unless user.helpdesk_agent
    pattern
  end

  def cp_user_event_info_pattern(expected_hash)
    event_info_hash = { ip_address: Thread.current[:current_ip] }
    event_info_hash.merge!(expected_hash)
  end
end
