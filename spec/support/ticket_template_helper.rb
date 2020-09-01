module TicketTemplateHelper

  def create_sample_tkt_templates(count = 3)
    @groups = []
    count.times { @groups << create_group(@account) }
    @all_agents_template = create_tkt_template({:name => "Template - All agents",:account_id => @account.id,
      :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]}})
    @user_template = create_personal_template(@agent.id)
    @grps_template = create_tkt_template({:name => "Template - Multiple Groups",:account_id => @account.id,
      :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups],:group_ids=>[@groups[0].id]}})
  end

  def create_tkt_template options
    options.symbolize_keys!
    options = template_default_options.merge(options)
    tkt_template = FactoryGirl.build(:ticket_templates, :name=>options[:name], :description=>Faker::Lorem.sentence(2),
                          :template_data => {"subject" => options[:subject], "status" => options[:status], "ticket_type" => options[:ticket_type],
                                             "group_id" => options[:group_id], "responder_id" => options[:responder_id], "priority" => options[:priority], "product_id" => options[:product_id], "tags" => options[:tags]
                                              },
                          :account_id=>options[:account_id],
                          :association_type => options[:association_type])

    tkt_template[:template_data][:source] = options[:source] if options[:source].present?
    (options[:attachments] || []).each do |att|
      tkt_template.attachments.build(:content => att[:resource],:description => Faker::Lorem.characters(10),:account_id => tkt_template.account_id)
    end
    tkt_template.save(:validate => false)
    accessible = tkt_template.create_accessible(:access_type => options[:accessible_attributes][:access_type])
    if (options[:accessible_attributes][:access_type] == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups])
      accessible.create_group_accesses(options[:accessible_attributes][:group_ids])
    elsif (options[:accessible_attributes][:access_type] == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users])
      accessible.create_user_accesses(options[:accessible_attributes][:user_ids])
    end
    tkt_template
  end

  def create_personal_template agent_id
    @groups = []
    @groups << create_group(@account)
    create_tkt_template({:name => "Template - Only Me",:account_id => @account.id,
      :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],:user_ids=>[agent_id]}})
  end

  def create_parent_child_template(count)
    @agent = get_admin
    @groups = []
    @child_templates = []
    3.times { @groups << create_group(@account) }
    @parent_template = create_tkt_template(name: Faker::Name.name,
                        association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent],
                        account_id: @account.id,
                        accessible_attributes: {
                                                access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                              },
                                         )
    count.times { @child_templates << create_child_template(@parent_template) }
  end

  def create_child_template(parent_templ)
    child_template = create_tkt_template(name: Faker::Name.name,
                    subject: 'Create child ticket using template',
                    association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child],
                    account_id: @account.id,
                    accessible_attributes: {
                    access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                          },
                                          )
    child_template.build_parent_assn_attributes(parent_templ.id)
    child_template.save
    return child_template
  end

  def create_ticket_fields
    tkt_custom_field_params.each do |params|
        
      flexifield_def_entry = FactoryGirl.build(:flexifield_def_entry, 
                                           :flexifield_def_id => @account.flexi_field_defs.find_by_name("Ticket_#{@account.id}").id,
                                           :flexifield_alias => "#{params[:name]}_#{@account.id}",
                                           :flexifield_name => params[:ff_name],
                                           :flexifield_coltype => params[:ff_coltype],
                                           :account_id => @account.id)
      flexifield_def_entry.save
      custom_field = FactoryGirl.build( :ticket_field, :account_id => @account.id,
                                                   :name => "#{params[:name]}_#{@account.id}",
                                                   :field_type => params[:type],
                                                   :flexifield_def_entry_id => flexifield_def_entry.id)
      custom_field.save
    end
  end

  def tkt_custom_field_params
    [
      { :type => "custom_number", :ff_name => "ff_int07", :ff_coltype => "number", :name=> "serial_number" },
      { :type => "custom_text", :ff_name => "ffs_07", :ff_coltype => "text", :name=> "branch" },
      { :type => "custom_paragraph", :ff_name => "ff_text07", :ff_coltype => "paragraph", :name=> "additional_info" },
      { :type => "custom_date", :ff_name => "ff_date07", :ff_coltype => "date", :name=> "date" },
      { :type => "custom_decimal", :ff_name => "ff_decimal07", :ff_coltype => "decimal", :name=> "average" },
      { :type => "custom_checkbox", :ff_name => "ff_boolean07", :ff_coltype => "checkbox", :name=> "availability" },
      { type: 'custom_date_time', ff_name: 'ff_date08', ff_coltype: 'date_time', name: 'appointment_time' }
    ]
  end

  def template_default_options
    {
      subject:        "sample tkt",
      status:         "2",
      ticket_type:    "Lead",
      group_id:       @groups[0].id,
      responder_id:   @agent.id,
      priority:       "1",
      product_id:     "",
      tags:           "tag1,tag2,tag3"
    }
  end
end