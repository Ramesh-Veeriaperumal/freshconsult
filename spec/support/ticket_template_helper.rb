module TicketTemplateHelper

  def create_sample_tkt_templates
    @groups = []
    3.times { @groups << create_group(@account) }
    @all_agents_template = create_tkt_template({:name => "Template - All agents",:account_id => @account.id,
      :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]}})
    @user_template = create_personal_template(@agent.id)
    @grps_template = create_tkt_template({:name => "Template - Multiple Groups",:account_id => @account.id,
      :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups],:group_ids=>[@groups[0].id]}})
  end

  def create_tkt_template options
    tkt_template = FactoryGirl.build(:ticket_templates, :name=>options[:name], :description=>Faker::Lorem.sentence(2),
                          :template_data => {:subject=>"sample tkt", :status=>"2", :ticket_type=>"Lead", :group_id=> @groups[0].id, :responder_id=> @agent.id, :priority=>"1", :product_id=>""},
                          :account_id=>options[:account_id])
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
    create_tkt_template({:name => "Template - Only Me",:account_id => @account.id,
      :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],:user_ids=>[agent_id]}})
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
      { :type => "custom_checkbox", :ff_name => "ff_boolean07", :ff_coltype => "checkbox", :name=> "availability" }
    ]
  end
end