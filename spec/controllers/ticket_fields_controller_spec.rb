require 'spec_helper'
include TicketFieldsHelper

describe TicketFieldsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
  end

  before(:each) do
    @request.host = @account.full_domain
    @default_fields = ticket_field_hash(@account.ticket_fields, @account)
    @default_fields.map{|f_d| f_d.delete(:level_three_present)}
    log_in(@user)
  end

  it "should go to the index page" do
    get 'index'
    response.should render_template "ticket_fields/index.html.erb"
    response.body.should =~ /Ticket Fields/
  end

  it "should create a custom field" do
    put :update, :jsonData => @default_fields.push({:type => "paragraph", 
                                                    :field_type => "custom_paragraph", 
                                                    :label => "Problem", 
                                                    :label_in_portal => "Problem", 
                                                    :description => "", 
                                                    :active => true, 
                                                    :required => false, 
                                                    :required_for_closure => false, 
                                                    :visible_in_portal => true, 
                                                    :editable_in_portal => true, 
                                                    :required_in_portal => false, 
                                                    :id => nil, 
                                                    :choices => [], 
                                                    :levels => [], 
                                                    :action => "create"}).to_json
    @account.ticket_fields.find_by_label("Problem").should be_an_instance_of(Helpdesk::TicketField)
  end

  it "should create a custom dependant field" do
    # ffs_01 and ffs_02 are created here
    labels = ["Nationality", "Player"]
    field_choices = [["South Africa","0",[["Jacques Kallis", "0"],["AB De Villiers", "0"],["Alan Donald", "0"]]],
                     ["England","0",[["Paul Collingwood", "0"],["Alec Stewart", "0"],["James Anderson", "0"]]]
                    ]
    put :update, :jsonData => @default_fields.push({:type => "dropdown", 
                                                    :field_type => "nested_field", 
                                                    :label => labels[0], 
                                                    :label_in_portal => labels[0], 
                                                    :description => "", 
                                                    :active => true, 
                                                    :required => false, 
                                                    :required_for_closure => false, 
                                                    :visible_in_portal => true, 
                                                    :editable_in_portal => true, 
                                                    :required_in_portal => false, 
                                                    :id => nil, 
                                                    :choices => field_choices,
                                                    :levels => [{:label => labels[1], :label_in_portal => labels[1], :description => "", :level => 2,
                                                                 :id => nil, :position => 4, :type => "dropdown", :action => "create"}
                                                               ],
                                                    :action => "create"}).to_json
    parent_label = @account.ticket_fields.find_by_label(labels[0])
    parent_label.should be_an_instance_of(Helpdesk::TicketField)
    parent_label.nested_ticket_fields.find_by_label(labels[1]).should be_an_instance_of(Helpdesk::NestedTicketField)
    parent_aus = parent_label.picklist_values.find_by_value("England")
    parent_aus.should be_an_instance_of(Helpdesk::PicklistValue)
    parent_aus.pickable_type.should eql "Helpdesk::TicketField"
    parent_aus.sub_picklist_values.find_by_value("Alec Stewart").should be_an_instance_of(Helpdesk::PicklistValue)
    parent_aus.sub_picklist_values.find_by_value("Alec Stewart").pickable_type.should eql "Helpdesk::PicklistValue"
  end

  it "should edit a custom field" do
    flexifield_def_entry = Factory.build(:flexifield_def_entry, 
                                         :flexifield_def_id => @account.flexi_field_defs.find_by_module("Ticket").id,
                                         :flexifield_alias => "solution_#{@account.id}",
                                         :flexifield_name => "ff_text07",
                                         :account_id => @account.id)
    flexifield_def_entry.save
    custom_field = Factory.build( :ticket_field, :account_id => @account.id,
                                                 :name => "solution_#{@account.id}",
                                                 :flexifield_def_entry_id => flexifield_def_entry.id)
    custom_field.save
    put :update, :jsonData => @default_fields.push({:field_type => "custom_paragraph", 
                                                    :id => custom_field.id, 
                                                    :name => "solution_#{@account.id}", 
                                                    :label => "Solution", 
                                                    :label_in_portal => "Solution", 
                                                    :description => "", 
                                                    :position => 3, 
                                                    :active => true, 
                                                    :required => false, 
                                                    :required_for_closure => false, 
                                                    :visible_in_portal => false, 
                                                    :editable_in_portal => false, 
                                                    :required_in_portal => false, 
                                                    :choices => [], 
                                                    :levels => nil, 
                                                    :field_options => nil, 
                                                    :type => "paragraph", 
                                                    :action => "edit"}).to_json
    custom_field = @account.ticket_fields.find_by_label("Solution")
    custom_field.should be_an_instance_of(Helpdesk::TicketField)
    custom_field.visible_in_portal.should be_false
    custom_field.editable_in_portal.should be_false
  end

  it "should edit a custom dependant field" do
    flexifield_def_entry = []
    labels = ['Nation', 'Memorial']
    # ffs_03 and ffs_04 are created here
    (0..1).each do |nested_field_id|
      flexifield_def_entry[nested_field_id] = Factory.build(:flexifield_def_entry, 
                                                            :flexifield_def_id => @account.flexi_field_defs.find_by_module("Ticket").id,
                                                            :flexifield_alias => "#{labels[nested_field_id].downcase}_#{@account.id}",
                                                            :flexifield_name => "ffs_0#{nested_field_id+3}",
                                                            :flexifield_order => 5,
                                                            :flexifield_coltype => "dropdown",
                                                            :account_id => @account.id)
      flexifield_def_entry[nested_field_id].save
    end

    parent_custom_field = Factory.build(:ticket_field, :account_id => @account.id,
                                        :name => "#{labels[0].downcase}_#{@account.id}",
                                        :label => labels[0],
                                        :label_in_portal => labels[0],
                                        :field_type => "nested_field",
                                        :description => "",
                                        :flexifield_def_entry_id => flexifield_def_entry[0].id)
    parent_custom_field.save

    nested_field = Factory.build(:nested_ticket_field, :account_id => @account.id,
                                 :name => "#{labels[1].downcase}_#{@account.id}",
                                 :flexifield_def_entry_id => flexifield_def_entry[1].id,
                                 :label => labels[1],
                                 :label_in_portal => labels[1],
                                 :ticket_field_id => parent_custom_field.id,
                                 :level => 2)
    nested_field.save

    field_choices = [["India","0",[["Taj Mahal", "0"],["Victoria Memorial", "0"],["The India Gate", "0"]]],
                     ["United States of America","0",
                      [["Statue of Liberty", "0"],["The Liberty Bell", "0"],["Washington Monument", "0"]]
                     ]
                    ]

    picklist_vals_l1, picklist_vals_l2 = [], []
    field_choices.map(&:first).each_with_index do |l1_val, index1|
      picklist_vals_l1 << Factory.build(:picklist_value, :account_id => @account.id,
                                        :pickable_type => 'Helpdesk::TicketField',
                                        :pickable_id => parent_custom_field.id,
                                        :position => index1+1,
                                        :value => l1_val)
      picklist_vals_l1.last.save

      field_choices[index1][2].map(&:first).each_with_index do |l2, index2|
        picklist_vals_l2 << Factory.build(:picklist_value, :account_id => @account.id,
                                          :pickable_type => 'Helpdesk::PicklistValue',
                                          :pickable_id => picklist_vals_l1[picklist_vals_l1.length-1].id,
                                          :position => index2+1,
                                          :value => l2)
        picklist_vals_l2.last.save
      end
    end

    put :update, :jsonData => @default_fields.push({:field_type => "nested_field", 
                                                    :id => parent_custom_field.id, 
                                                    :name => "#{labels[0].downcase}_#{@account.id}",
                                                    :label => labels[0],
                                                    :label_in_portal => labels[0],
                                                    :description => "",
                                                    :position => 5,
                                                    :active => true,
                                                    :required => false,
                                                    :required_for_closure => false,
                                                    :visible_in_portal => false,
                                                    :editable_in_portal => false,
                                                    :required_in_portal => false,
                                                    :choices => field_choices,
                                                    :levels => [{:label=>"Monument", :label_in_portal=>"Monument", :description=>"", :level=>2,
                                                                 :id => nested_field.id, :position=>5, :type=>"dropdown", :name => "monument_#{@account.id}",
                                                                 :action=>"edit"}
                                                               ],
                                                    :field_options => nil,
                                                    :type => "dropdown",
                                                    :action => "edit"}).to_json

    parent_custom_field = @account.ticket_fields.find_by_label(labels[0])
    parent_custom_field.should be_an_instance_of(Helpdesk::TicketField)
    parent_custom_field.picklist_values.find_by_value("United States of America").should be_an_instance_of(Helpdesk::PicklistValue)
    parent_custom_field.picklist_values.find_by_value("United States of America").pickable_type.should eql "Helpdesk::TicketField"

    parent_usa = parent_custom_field.picklist_values.find_by_value("United States of America")
    parent_usa.should be_an_instance_of(Helpdesk::PicklistValue)
    parent_usa.pickable_type.should eql "Helpdesk::TicketField"
    parent_usa.sub_picklist_values.find_by_value("Statue of Liberty").should be_an_instance_of(Helpdesk::PicklistValue)
    parent_usa.sub_picklist_values.find_by_value("Statue of Liberty").pickable_type.should eql "Helpdesk::PicklistValue"
    parent_custom_field.visible_in_portal.should be_false
    parent_custom_field.editable_in_portal.should be_false
    parent_custom_field.nested_ticket_fields.find_by_label("Monument").should be_an_instance_of(Helpdesk::NestedTicketField)
    parent_custom_field.nested_ticket_fields.find_by_label(labels[1]).should be_nil
  end

  it "should delete a custom field" do
    flexifield_def_entry = Factory.build(:flexifield_def_entry, 
                                         :flexifield_def_id => @account.flexi_field_defs.find_by_module("Ticket").id,
                                         :flexifield_alias => "incident_#{@account.id}",
                                         :flexifield_name => "ff_text03",
                                         :account_id => @account.id)
    flexifield_def_entry.save
    custom_field = Factory.build(:ticket_field, :account_id => @account.id,
                                 :name => "incident_#{@account.id}",
                                 :label => "Incident",
                                 :label_in_portal => "Incident",
                                 :flexifield_def_entry_id => flexifield_def_entry.id)
    custom_field.save
    put :update, :jsonData => @default_fields.push({:field_type => "custom_paragraph", 
                                                    :id => custom_field.id, 
                                                    :name => "incident_#{@account.id}", 
                                                    :label => "Incident", 
                                                    :label_in_portal => "Incident", 
                                                    :description => "Test", 
                                                    :position => 1, 
                                                    :active => true, 
                                                    :required => false, 
                                                    :required_for_closure => false, 
                                                    :visible_in_portal => true, 
                                                    :editable_in_portal => true, 
                                                    :required_in_portal => false, 
                                                    :choices => [], 
                                                    :levels => nil, 
                                                    :field_options => nil, 
                                                    :type => "paragraph", 
                                                    :action => "delete"}).to_json
    @account.ticket_fields.find_by_label("Incident").should be_nil
  end

  it "should delete a custom dependant field" do
    flexifield_def_entry = []
    labels = ['Country', 'State', 'City']
    # ffs_05, ffs_06 and ffs_07 are created here
    (0..2).each do |nested_field_id|
      flexifield_def_entry[nested_field_id] = Factory.build(:flexifield_def_entry, 
                                                            :flexifield_def_id => @account.flexi_field_defs.find_by_module("Ticket").id,
                                                            :flexifield_alias => "#{labels[nested_field_id].downcase}_#{@account.id}",
                                                            :flexifield_name => "ffs_0#{nested_field_id+5}",
                                                            :flexifield_order => 6,
                                                            :flexifield_coltype => "dropdown",
                                                            :account_id => @account.id)
      flexifield_def_entry[nested_field_id].save
    end

    parent_custom_field = Factory.build(:ticket_field, :account_id => @account.id,
                                        :name => "#{labels[0].downcase}_#{@account.id}",
                                        :label => labels[0],
                                        :label_in_portal => labels[0],
                                        :field_type => "nested_field",
                                        :description => "",
                                        :flexifield_def_entry_id => flexifield_def_entry[0].id)
    parent_custom_field.save

    nested_field_vals = []
    (1..2).each do |nf|
      nested_field_vals[nf-1] = Factory.build(:nested_ticket_field, :account_id => @account.id,
                                   :name => "#{labels[nf].downcase}_#{@account.id}",
                                   :flexifield_def_entry_id => flexifield_def_entry[nf].id,
                                   :label => labels[nf],
                                   :label_in_portal => labels[nf],
                                   :ticket_field_id => parent_custom_field.id,
                                   :level => nf+1)
      nested_field_vals[nf-1].save
    end
    
    field_choices = [["Australia", "0",
                       [["New South Wales", "0", [["Sydney", "0"]]],
                        ["Queensland", "0", [["Brisbane", "0"]]]
                       ]
                      ],
                      ["USA", "0",
                        [["California", "0", [["Burlingame", "0"], ["Los Angeles", "0"]]],
                         ["Texas", "0", [["Houston", "0"], ["Dallas", "0"]]]
                        ]
                      ]
                    ]
    field_choices_del = [["Australia", "0",
                          [["New South Wales", "0"], ["Queensland", "0"]]
                         ],
                         ["USA", "0",
                          [["California", "0"], ["Texas", "0"]]
                         ]
                        ]

    picklist_vals_l1, picklist_vals_l2, picklist_vals_l3 = [], [], []
    field_choices.map(&:first).each_with_index do |l1_val, index1|
      picklist_vals_l1 << Factory.build(:picklist_value, :account_id => @account.id,
                                        :pickable_type => 'Helpdesk::TicketField',
                                        :pickable_id => parent_custom_field.id,
                                        :position => index1+1,
                                        :value => l1_val)
      picklist_vals_l1.last.save

      field_choices[index1][2].map(&:first).each_with_index do |l2_val, index2|
        picklist_vals_l2 << Factory.build(:picklist_value, :account_id => @account.id,
                                          :pickable_type => 'Helpdesk::PicklistValue',
                                          :pickable_id => picklist_vals_l1[picklist_vals_l1.length-1].id,
                                          :position => index2+1,
                                          :value => l2_val)
        picklist_vals_l2.last.save
        field_choices[index1][2][index2][2].map(&:first).each_with_index do |l3, index3|
          picklist_vals_l3 << Factory.build(:picklist_value, :account_id => @account.id,
                                            :pickable_type => 'Helpdesk::PicklistValue',
                                            :pickable_id => picklist_vals_l2[picklist_vals_l2.length-1].id,
                                            :position => index3+1,
                                            :value => l3)
          picklist_vals_l3.last.save
        end
      end
    end

    put :update, :jsonData => @default_fields.push({:field_type => "nested_field", 
                                                    :id => parent_custom_field.id, 
                                                    :name => "#{labels[0].downcase}_#{@account.id}",
                                                    :label => labels[0],
                                                    :label_in_portal => labels[0],
                                                    :description => "",
                                                    :position => 6,
                                                    :active => true,
                                                    :required => false,
                                                    :required_for_closure => false,
                                                    :visible_in_portal => true,
                                                    :editable_in_portal => true,
                                                    :required_in_portal => false,
                                                    :choices => field_choices_del,
                                                    :levels => [{:label => "State", :label_in_portal => "State", :description => "",
                                                                 :level => 2, :id => nested_field_vals[0].id, :position => 6, :type => "dropdown", :action => "edit"},
                                                                {:label => "", :label_in_portal =>"", :description=>"",
                                                                 :level => 3, :id => nested_field_vals[1].id, :position => 6, :type => "dropdown", :action => "delete"}
                                                               ],
                                                    :field_options => nil,
                                                    :type => "dropdown",
                                                    :action => "edit"}).to_json

    parent_custom_field = @account.ticket_fields.find_by_label(labels[0])
    parent_custom_field.should be_an_instance_of(Helpdesk::TicketField)
    parent_custom_field.level_three_present.should eql false
  end
end