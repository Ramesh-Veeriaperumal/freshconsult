['contact_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

module CoreUsersTestHelper
  include ContactFieldsTestHelper

  XSS_SCRIPT_TEXT = "<script> alert('hi'); </script>"
  CUSTOM_FIELDS_TYPES = %w(text paragraph checkbox number)
  CUSTOM_FIELDS_CONTENT_BY_TYPE = { 'text' => XSS_SCRIPT_TEXT, 'paragraph' =>  XSS_SCRIPT_TEXT,
          'checkbox' => true, 'number' => 1 }  # 'decimal' => 1.1

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
    role_id = @account.roles.find_by_name("Agent").id
    acc_subscription = Account.current.subscription
    old_subscription_state = acc_subscription.state
    acc_subscription.state = 'trial'
    acc_subscription.save
    new_agent = FactoryGirl.build(:agent,
                                  :account_id => account.id,
                                  :available => 1,
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
    if options[:unique_external_id]
      new_user.unique_external_id = options[:unique_external_id]
    end
    new_user.agent = new_agent
    new_user.privileges = options[:privileges] || account.roles.find_by_id(role_id).privileges
    v = new_user.save_without_session_maintenance
    if options[:group_id]
      ag_grp = AgentGroup.new(:user_id => new_agent.user_id , :account_id =>  account.id, :group_id => options[:group_id])
      ag_grp.save!
    end
    unless v 
      Rails.logger.debug "#{new_user.errors.messages}"   
      throw Exception.new("Failed to create user #{new_user.errors}");
    end
    new_user.reload
  ensure
    acc_subscription.state = old_subscription_state
    acc_subscription.save
  end

  # def build_tags(tag_names)
  #   tags = []
  #   existing_tags = Helpdesk::Tag.where(account_id: @account.id)
  #   tag_names_taken = existing_tags.map(&:name)
  #   tag_names -= tag_names_taken if tag_names.present?
  #   tag_names.each do |tag_name|
  #     tags << Helpdesk::Tag.new(name: tag_name)
  #   end
  #   [*tags, *existing_tags]
  # end

  def add_new_user(account, options={})
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
                                  tag_names: options[:tag_names] || "")
    if options[:unique_external_id]
      new_user.unique_external_id = options[:unique_external_id]
    end
    new_user.custom_field = options[:custom_fields] if options.key?(:custom_fields)
    new_user.save_without_session_maintenance
    new_user.reload
  end

  def act_as_scoped_agent(permission, &block)
    user_agent = User.current.agent
    prev_permission = user_agent.ticket_permission
    user_agent.ticket_permission = permission
    user_agent.save!
    ag_grp = AgentGroup.new(user_id: User.current.id , account_id: @account.id, group_id: @account.groups.first.id)
    ag_grp.save!
    yield
  ensure
    user_agent.ticket_permission = prev_permission
    user_agent.save
  end

  def add_user_draft_attachments(params={})
    file = File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))
    user_id = params[:user_id] || add_new_user(@account).id
    att = Helpdesk::Attachment.new(content: file, account_id: @account.id, attachable_type: "UserDraft", attachable_id: user_id)
    att.save
  end

  def create_user_with_xss other_object_params = {}
    params  = create_user_params_with_xss other_object_params
    contact = add_new_user @account, params
  end

  def create_user_params_with_xss other_object_params
    params = {}
    params[:custom_fields] = {}
    CUSTOM_FIELDS_TYPES.each do |field_type|
      cf_params = cf_params(type: field_type, field_type: "custom_#{field_type}", label: "test_custom_#{field_type}", editable_in_signup: 'true')
      custom_field = create_custom_contact_field(cf_params)
      params[:custom_fields][:"#{custom_field.name}"] = CUSTOM_FIELDS_CONTENT_BY_TYPE[field_type]
    end
    Account.current.reload
    params.merge(other_object_params)
  end 
  
end