require_relative '../test_helper'
Sidekiq::Testing.fake!

class TicketFieldsControllerTest < ActionController::TestCase

  include TicketFieldsTestHelper
  include Admin::AdvancedTicketing::FieldServiceManagement::Util

  def setup
    super
    Sidekiq::Worker.clear_all
    before_all
    Account.current.rollback(:nested_field_revamp) # nested_field_revamp should only be available for UI based request
    Account.current.rollback(:ticket_field_revamp) # its for emberized ticket field/ test cases are old so affect model variables
    Account.current.add_feature(:custom_ticket_fields)
  end

  def teardown
    Account.current.revoke_feature(:custom_ticket_fields)
    super
  end

  @@before_all_run = false

  def before_all
    @account.sections.map(&:destroy)
    @account.ticket_fields_with_nested_fields.custom_fields.where(level: nil).each {|custom_field| custom_field.destroy } # PRE-RAILS: removed child level fields for reset
    @default_fields = ticket_field_hash(@account.ticket_fields, @account)
    @default_fields.map{|f_d| f_d.delete(:level_three_present)}
    CentralPublishWorker::TicketFieldWorker.jobs.clear
    return if @@before_all_run
    @account.ticket_fields.custom_fields.each(&:destroy)
    @@before_all_run = true
  end

  def test_index
    create_custom_field('section_checkbox', 'checkbox', '09')
    get :index
    assert_response 200
  end

  def test_create_payload
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
                                                    :position => 100,
                                                    :action => "create"}).to_json
    assert_response :redirect
    assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 1
    job = CentralPublishWorker::TicketFieldWorker.jobs.first.deep_symbolize_keys
    field = Account.current.ticket_fields.find_by_label("Problem")
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:create)
    event_params = event_args(field, :create)
    assert_equal job[:args][1].slice(*event_params.keys), event_params
    payload = field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field))    
  end

  def test_edit_a_custom_field
    field = create_custom_field("test_custom_publish_text", "text")
    put :update, :jsonData => @default_fields.push({
                                                    :field_type => field.field_type,
                                                    :name => field.name,
                                                    :label => "#{field.label} edit",
                                                    :label_in_portal => "#{field.label_in_portal} edit",
                                                    :description => "",
                                                    :active => true,
                                                    :required => true,
                                                    :required_for_closure => true,
                                                    :visible_in_portal => true,
                                                    :editable_in_portal => true,
                                                    :required_in_portal => false,
                                                    :id => field.id,
                                                    :choices => [],
                                                    :levels => [],
                                                    :position => 100,
                                                    :action => "edit"}).to_json
    assert_response :redirect
    # assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 1
    job = CentralPublishWorker::TicketFieldWorker.jobs.first.deep_symbolize_keys
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:update)
    model_changes = {
      :label => [field.label, "#{field.label} edit"],
      :label_in_portal => [field.label_in_portal, "#{field.label_in_portal} edit"],
      :required => [false, true],
      :required_for_closure => [false, true]
    }
    event_params = event_args(field, :update, model_changes)
    assert_equal job[:args][1].slice(*event_params.keys), event_params    
    payload = field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field))
  end

  def test_create_a_custom_dependent_field
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
                                                    :action => "create",
                                                    :position => 100}).to_json

      assert_response :redirect
    # assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 1
    job = CentralPublishWorker::TicketFieldWorker.jobs.first.deep_symbolize_keys
    field = @account.ticket_fields.find_by_label(labels[0])
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:create)
    event_params = event_args(field, :create)
    assert_equal job[:args][1].slice(*event_params.keys), event_params    
    payload = field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field))
  end

  def test_create_a_custom_dropdown_field
    # ffs_03 is created here
    labels = ["Freshproducts"]
    field_choices = [["Freshdesk","0"], ["Freshservice","0"], ["Freshchat","0"]]
    pv_attr = [{"value" => "Freshdesk"},
               {"value" => "Freshservice"},
               {"value" => "Freshchat"}
               ]
    CentralPublishWorker::TicketFieldWorker.jobs.clear
    put :update, :jsonData => @default_fields.push({:type => "dropdown",
                                                    :field_type => "custom_dropdown",
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
                                                    :picklist_values_attributes => pv_attr,
                                                    :levels => nil,
                                                    :position => 100,
                                                    :action => "create"}).to_json
    assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 4
    job = CentralPublishWorker::TicketFieldWorker.jobs.first.deep_symbolize_keys
    field = @account.ticket_fields.find_by_label(labels[0])
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:create)
    event_params = event_args(field, :create)
    assert_equal job[:args][1].slice(*event_params.keys), event_params    
    payload = field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field))
    CentralPublishWorker::TicketFieldWorker.jobs.clear
  end

  def test_edit_a_custom_field
    flexifield_def_entry = FactoryGirl.build(:flexifield_def_entry, 
                                         :flexifield_def_id => @account.flexi_field_defs.find_by_name("Ticket_#{@account.id}").id,
                                         :flexifield_alias => "solution_#{@account.id}",
                                         :flexifield_name => "ff_text03",
                                         :account_id => @account.id)
    flexifield_def_entry.save
    custom_field = FactoryGirl.build( :ticket_field, :account_id => @account.id,
                                      :name => "solution_#{@account.id}",
                                      :flexifield_def_entry_id => flexifield_def_entry.id,
                                      :description => "")
    custom_field.save
    CentralPublishWorker::TicketFieldWorker.jobs.clear
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
                                                    :field_options => {},
                                                    :type => "paragraph",
                                                    :action => "edit"}).to_json
    custom_field_new = @account.ticket_fields.find_by_label("Solution")
    model_changes = {
      :label =>[custom_field.label, custom_field_new.label],
      :label_in_portal =>[custom_field.label_in_portal, custom_field_new.label_in_portal],
      :visible_in_portal => [custom_field.visible_in_portal, custom_field_new.visible_in_portal],
      :editable_in_portal => [custom_field.editable_in_portal, custom_field_new.editable_in_portal],
      :updated_at => [ts(custom_field.updated_at), ts(custom_field_new.updated_at)]
    }
    # assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 1
    job = CentralPublishWorker::TicketFieldWorker.jobs.last.deep_symbolize_keys
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:update)
    event_params = event_args(custom_field_new, :update, model_changes)
    assert_equal job[:args][1].slice(*event_params.keys), event_params    
    payload = custom_field_new.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(custom_field_new))
  end

  def test_edit_a_custom_dropdown_field
    labels = ['Freshmovies']
    # ffs_04 is created here
    flexifield_def_entry = FactoryGirl.build(:flexifield_def_entry,
                                             :flexifield_def_id => @account.flexi_field_defs.find_by_module("Ticket").id,
                                             :flexifield_alias => "#{labels[0].downcase}_#{@account.id}",
                                             :flexifield_name => "ffs_04",
                                             :flexifield_order => 5,
                                             :flexifield_coltype => "dropdown",
                                             :account_id => @account.id)
    flexifield_def_entry.save

    custom_field = FactoryGirl.build(:ticket_field, :account_id => @account.id,
                                            :name => "#{labels[0].downcase}_#{@account.id}",
                                            :label => labels[0],
                                            :label_in_portal => labels[0],
                                            :field_type => "custom_dropdown",
                                            :description => "",
                                            :flexifield_def_entry_id => flexifield_def_entry.id)
    custom_field.save

    field_choices = [["Get Smart","0"],
                     ["Pursuit of Happiness","0"],
                     ["Armaggedon","0"]
                     ]
    pv_attr = [{"value" => "Get Smart"},
               {"value" => "Pursuit of Happiness"},
               {"value" => "Armaggedon"}
               ]

    picklist_vals_l1 = []
    field_choices.map(&:first).each_with_index do |l1_val, index1|
      picklist_vals_l1 << FactoryGirl.build(:picklist_value, :account_id => @account.id,
                                            :pickable_type => 'Helpdesk::TicketField',
                                            :pickable_id => custom_field.id,
                                            :position => index1+1,
                                            :value => l1_val)
      picklist_vals_l1.last.save
    end
    CentralPublishWorker::TicketFieldWorker.jobs.clear
    put :update, :jsonData => @default_fields.push({:field_type => "custom_dropdown",
                                                  :id => custom_field.id,
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
                                                  :choices => [["Get Smart","1"],
                                                               ["Pursuit of Happiness","2"],
                                                               ["Cast Away","3"]
                                                               ],
                                                  :picklist_values_attributes => [{"value" => "Get Smart", :id => picklist_vals_l1[0].id},
                                                                                  {"value" => "Pursuit of Happiness", :id => picklist_vals_l1[1].id},
                                                                                  {"value" => "Cast Away", :id => picklist_vals_l1[2].id }
                                                                                  ],
                                                  :levels => nil,
                                                  :field_options => {},
                                                  :type => "dropdown",
                                                  :action => "edit"}).to_json

    custom_field_new = @account.ticket_fields.find_by_label(labels[0])
    model_changes = {
      :position =>[custom_field.position, custom_field_new.position],
      :visible_in_portal => [custom_field.visible_in_portal, custom_field_new.visible_in_portal],
      :editable_in_portal => [custom_field.editable_in_portal, custom_field_new.editable_in_portal],
      :updated_at => [ts(custom_field.updated_at), ts(custom_field_new.updated_at)]
    }
    assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 2
    job = CentralPublishWorker::TicketFieldWorker.jobs.select { |a| a['args'][0] == 'ticket_field_update' }.last.deep_symbolize_keys
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:update)
    event_params = event_args(custom_field_new, :update, model_changes)
    assert_equal job[:args][1].slice(*event_params.keys), event_params    
    payload = custom_field_new.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(custom_field_new))
  end

  def test_edit_a_custom_dependent_field
    flexifield_def_entry = []
    labels = ['Nation', 'Memorial']
    # ffs_05 and ffs_06 are created here
    (0..1).each do |nested_field_id|
      flexifield_def_entry[nested_field_id] = FactoryGirl.build(:flexifield_def_entry, 
                                                            :flexifield_def_id => @account.flexi_field_defs.find_by_name("Ticket_#{@account.id}").id,
                                                            :flexifield_alias => "#{labels[nested_field_id].downcase}_#{@account.id}",
                                                            :flexifield_name => "ffs_0#{nested_field_id+5}",
                                                            :flexifield_order => 5,
                                                            :flexifield_coltype => "dropdown",
                                                            :account_id => @account.id)
      flexifield_def_entry[nested_field_id].save
    end

    custom_field = FactoryGirl.build(:ticket_field, :account_id => @account.id,
                                            :name => "#{labels[0].downcase}_#{@account.id}",
                                            :label => labels[0],
                                            :label_in_portal => labels[0],
                                            :field_type => "nested_field",
                                            :description => "",
                                            :flexifield_def_entry_id => flexifield_def_entry[0].id)
    custom_field.save

    nested_field = FactoryGirl.build(:nested_ticket_field, :account_id => @account.id,
                                     :name => "#{labels[1].downcase}_#{@account.id}",
                                     :flexifield_def_entry_id => flexifield_def_entry[1].id,
                                     :label => labels[1],
                                     :label_in_portal => labels[1],
                                     :ticket_field_id => custom_field.id,
                                     :level => 2)
    nested_field.save

    field_choices = [["India","0",[["Taj Mahal", "0"],["Victoria Memorial", "0"],["The India Gate", "0"]]],
                     ["United States of America","0",
                      [["Statue of Liberty", "0"],["The Liberty Bell", "0"],["Washington Monument", "0"]]
                      ]
                     ]

    picklist_vals_l1, picklist_vals_l2 = [], []
    field_choices.map(&:first).each_with_index do |l1_val, index1|
      picklist_vals_l1 << FactoryGirl.build(:picklist_value, :account_id => @account.id,
                                            :pickable_type => 'Helpdesk::TicketField',
                                            :pickable_id => custom_field.id,
                                            :position => index1+1,
                                            :value => l1_val)
      picklist_vals_l1.last.save

      field_choices[index1][2].map(&:first).each_with_index do |l2, index2|
        picklist_vals_l2 << FactoryGirl.build(:picklist_value, :account_id => @account.id,
                                              :pickable_type => 'Helpdesk::PicklistValue',
                                              :pickable_id => picklist_vals_l1[picklist_vals_l1.length-1].id,
                                              :position => index2+1,
                                              :value => l2)
        picklist_vals_l2.last.save
      end
    end

    CentralPublishWorker::TicketFieldWorker.jobs.clear

    put :update, :jsonData => @default_fields.push({:field_type => "nested_field",
                                                    :id => custom_field.id,
                                                    :name => "#{labels[0].downcase}_#{@account.id}",
                                                    :label => labels[0],
                                                    :label_in_portal => labels[0],
                                                    :description => "",
                                                    :position => 7,
                                                    :active => true,
                                                    :required => false,
                                                    :required_for_closure => false,
                                                    :visible_in_portal => false,
                                                    :editable_in_portal => false,
                                                    :required_in_portal => false,
                                                    :choices => field_choices,
                                                    :levels => [{:label=>"Monument", :label_in_portal=>"Monument", :description=>"", :level=>2,
                                                                 :id => nested_field.id, :position=>5, :type=>"dropdown",
                                                                 :action=>"edit"}
                                                                ],
                                                    :field_options => {},
                                                    :type => "dropdown",
                                                    :action => "edit"}).to_json

    custom_field_new = @account.ticket_fields.find_by_label(labels[0])
    model_changes = {
      :position =>[custom_field.position, custom_field_new.position],
      :visible_in_portal => [custom_field.visible_in_portal, custom_field_new.visible_in_portal],
      :editable_in_portal => [custom_field.editable_in_portal, custom_field_new.editable_in_portal],
      :updated_at => [ts(custom_field.updated_at), ts(custom_field_new.updated_at)]
    }
    assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 1
    job = CentralPublishWorker::TicketFieldWorker.jobs.last.deep_symbolize_keys
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:update)
    event_params = event_args(custom_field_new, :update, model_changes)
    assert_equal job[:args][1].slice(*event_params.keys), event_params    
    payload = custom_field_new.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(custom_field_new))
  end

  def test_delete_a_custom_field
    flexifield_def_entry = FactoryGirl.build(:flexifield_def_entry, 
                                         :flexifield_def_id => @account.flexi_field_defs.find_by_name("Ticket_#{@account.id}").id,
                                         :flexifield_alias => "incident_#{@account.id}",
                                         :flexifield_name => "ff_text04",
                                         :account_id => @account.id)
    flexifield_def_entry.save
    custom_field = FactoryGirl.build(:ticket_field, :account_id => @account.id,
                                     :name => "incident_#{@account.id}",
                                     :label => "Incident",
                                     :label_in_portal => "Incident",
                                     :flexifield_def_entry_id => flexifield_def_entry.id)
    custom_field.save

    CentralPublishWorker::TicketFieldWorker.jobs.clear

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
                                                    :field_options => {},
                                                    :type => "paragraph",
                                                    :action => "delete"}).to_json

    assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 1
    job = CentralPublishWorker::TicketFieldWorker.jobs.last.deep_symbolize_keys
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:destroy)
    event_params = event_args(custom_field, :destroy)
    assert_equal job[:args][1].slice(*event_params.keys), event_params    
    payload = custom_field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(custom_field))
  end
  
  # Enter Section Fields

  def test_create_a_section_with_section_fields
    parent_ticket_field = @account.ticket_fields.find_by_field_type("default_ticket_type")
    pl_value = parent_ticket_field.picklist_values.create(:value => Faker::Lorem.characters(6))
    CentralPublishWorker::TicketFieldWorker.jobs.clear
    put :update, :jsonData => @default_fields.push({:type => "paragraph",
                                                    :field_type => "custom_paragraph",
                                                    :label => "Section Field 1",
                                                    :label_in_portal => "Section Field 1",
                                                    :description => "",
                                                    :active => true,
                                                    :required => false,
                                                    :required_for_closure => false,
                                                    :visible_in_portal => true,
                                                    :editable_in_portal => true,
                                                    :required_in_portal => false,
                                                    :id => nil,
                                                    :field_options => {:section => true},
                                                    :choices => [],
                                                    :levels => [],
                                                    :position => 100,
                                                    :action => "create"}).to_json,
                :jsonSectionData => [{
                                        :label => "Section 1", 
                                        :picklist_ids => [{ "picklist_value_id" => pl_value.id }], 
                                        :action => "save", 
                                        :parent_ticket_field_id => parent_ticket_field.id, 
                                        :section_fields => [{
                                            :ticket_field_name => "Section Field 1", 
                                            :parent_ticket_field_id => parent_ticket_field.id, 
                                            :position => 1
                                        }]
                                    }].to_json
    new_field = @account.ticket_fields.find_by_label("Section Field 1")
    parent_ticket_field_new = @account.ticket_fields.find_by_field_type("default_ticket_type")
    # assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 1
    # Section Field
    job = CentralPublishWorker::TicketFieldWorker.jobs.first.deep_symbolize_keys
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:create)
    event_params = event_args(new_field, :create)
    assert_equal job[:args][1].slice(*event_params.keys), event_params

    # Parent field
    @account.reload
    section = @account.sections.last
    model_changes = {
      :sections=>[
        {:id => section.id, :label => section.label, :associated_picklist_values=>[], :section_fields=>[new_field.id]}, 
        {:id => section.id, :label => section.label, :associated_picklist_values=>[pl_value.value], :section_fields=>[new_field.id]}
      ],
      :updated_at=>[ts(parent_ticket_field.updated_at), ts(parent_ticket_field_new.updated_at)]
    }
    job = CentralPublishWorker::TicketFieldWorker.jobs.last.deep_symbolize_keys
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:update)
    event_params = event_args(parent_ticket_field_new, :update, model_changes)
    assert_equal job[:args][1].slice(*event_params.keys), event_params
    payload = parent_ticket_field_new.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(parent_ticket_field_new))
    payload = new_field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(new_field))
    # Discarding changes
    pl_value.destroy
  end

  def test_section_limit_on_update_with_fsm_enabled
    dd_field1 = create_custom_field_dropdown_with_sections('dropdown_1', %w[AA BB])
    section1 = construct_section('section_custom_dropdown_limit1', dd_field1.id)
    dd_field2 = create_custom_field_dropdown_with_sections('dropdown_2', %w[XX YY])
    section2 = construct_section('section_custom_dropdown_limit2', dd_field2.id)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    perform_fsm_operations
    assert_equal Helpdesk::TicketField::FSM_SECTION_LIMIT, @account.sections.count
    put :update, jsonData: ticket_field_hash(@account.ticket_fields, @account).to_json, jsonSectionData: sections_field_hash(@account.sections).to_json
    assert_response :redirect
    assert_equal Helpdesk::TicketField::FSM_SECTION_LIMIT, @account.sections.count
    assert_equal Helpdesk::TicketField::FSM_SECTION_LIMIT, @account.section_parent_fields.count
  ensure
    dd_field1.try(:destroy)
    section1.try(:destroy)
    dd_field2.try(:destroy)
    section2.try(:destroy)
    Account.any_instance.unstub(:field_service_management_enabled?)
    cleanup_fsm
  end

  def test_section_limit_on_update_with_fsm_disabled
    dd_field1 = create_custom_field_dropdown_with_sections('dropdown_1', %w[AA BB])
    section1 = construct_section('section_custom_dropdown_limit1', dd_field1.id)
    dd_field2 = create_custom_field_dropdown_with_sections('dropdown_2', %w[XX YY])
    section2 = construct_section('section_custom_dropdown_limit2', dd_field2.id)
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    perform_fsm_operations
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    assert_equal Helpdesk::TicketField::FSM_SECTION_LIMIT, @account.sections.count
    put :update, jsonData: ticket_field_hash(@account.ticket_fields, @account).to_json, jsonSectionData: sections_field_hash(@account.sections).to_json
    assert_response :redirect
    assert_equal Helpdesk::TicketField::FSM_SECTION_LIMIT, @account.sections.count
    assert_equal Helpdesk::TicketField::FSM_SECTION_LIMIT, @account.section_parent_fields.count
  ensure
    dd_field1.try(:destroy)
    section1.try(:destroy)
    dd_field2.try(:destroy)
    section2.try(:destroy)
    Account.any_instance.unstub(:field_service_management_enabled?)
    cleanup_fsm
  end

  def test_section_limit_on_update
    type_field = @account.ticket_fields_with_nested_fields.find_by_field_type('default_ticket_type')
    if type_field.field_options['section_present']
      type_field.field_options.delete('section_present')
      type_field.save!
    end
    dd_field1 = create_custom_field_dropdown_with_sections('dropdown_1', %w[AA BB])
    section1 = construct_section('section_custom_dropdown_limit1', dd_field1.id)
    dd_field2 = create_custom_field_dropdown_with_sections('dropdown_2', %w[XX YY])
    section2 = construct_section('section_custom_dropdown_limit2', dd_field2.id)
    dd_field3 = create_custom_field_dropdown_with_sections('dropdown_3', %w[PP QQ])
    section3 = construct_section('section_custom_dropdown_limit3', dd_field3.id)
    assert_equal 3, @account.sections.count
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    put :update, jsonData: ticket_field_hash(@account.ticket_fields, @account).to_json, jsonSectionData: sections_field_hash(@account.sections).to_json
    assert_response :redirect
    assert_equal Helpdesk::TicketField::SECTION_LIMIT, @account.sections.count
    assert_equal Helpdesk::TicketField::SECTION_LIMIT, @account.section_parent_fields.count
  ensure
    dd_field1.try(:destroy)
    section1.try(:destroy)
    dd_field2.try(:destroy)
    section2.try(:destroy)
    dd_field3.try(:destroy)
    section3.try(:destroy)
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  def test_edit_status_field
    field = @account.ticket_fields.find_by_name('status')
    put :update, :jsonData => @default_fields.push({
                                                    :field_type => field.field_type,
                                                    :name => field.name,
                                                    :label => "Status name",
                                                    :label_in_portal => "Status name",
                                                    :description => "Ticket status",
                                                    :active => true,
                                                    :required => true,
                                                    :required_for_closure => true,
                                                    :visible_in_portal => true,
                                                    :editable_in_portal => true,
                                                    :required_in_portal => false,
                                                    :id => field.id,
                                                    choices: status_choices,
                                                    :levels => [],
                                                    :action => "edit"}).to_json
    assert_response :redirect
    # assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 1
    acc_id = Account.current.id
    Account.find(acc_id).make_current
    field_new = @account.ticket_fields.find_by_name('status')
    # assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 1
    job = CentralPublishWorker::TicketFieldWorker.jobs.first.deep_symbolize_keys
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:update)
    model_changes = {
      :label=>[field.label, field_new.label],
      :label_in_portal=>[field.label_in_portal, field_new.label_in_portal],
      :required_for_closure => [false, true],
      :editable_in_portal => [false, true],
      :updated_at=>[ts(field.updated_at), ts(field_new.updated_at)]
    }
    event_params = event_args(field, :update, model_changes)
    assert_equal job[:args][1].slice(*event_params.keys), event_params
    payload = field_new.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field_new))
    # Discarding changes
    field_new.update_attributes(
      {
        :label=> field.label,
        :label_in_portal=> field.label_in_portal,
        :required_for_closure => false,
        :editable_in_portal => false
      })
  end

  def test_edit_priority_field
    field = @account.ticket_fields.find_by_name('priority')
    field_updated = field.updated_at
    put :update, :jsonData => @default_fields.push({
                                                    :field_type => field.field_type,
                                                    :name => field.name,
                                                    :label => "Priority Name",
                                                    :label_in_portal => "Priority Name",
                                                    :description => "Ticket priority",
                                                    :active => true,
                                                    :required => true,
                                                    :required_for_closure => true,
                                                    :visible_in_portal => true,
                                                    :editable_in_portal => true,
                                                    :required_in_portal => false,
                                                    :id => field.id,
                                                    :choices => [],
                                                    :levels => [],
                                                    :action => "edit"}).to_json
    assert_response :redirect
    # assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 1
    field_new = @account.ticket_fields.find_by_name('priority')
    # assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 1
    job = CentralPublishWorker::TicketFieldWorker.jobs.first.deep_symbolize_keys
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:update)
    model_changes = {
      :label=>[field.label, field_new.label],
      :label_in_portal=>[field.label_in_portal, field_new.label_in_portal],
      :required_for_closure=>[false, true],
      :visible_in_portal=>[false, true],
      :editable_in_portal=>[false, true],
      :updated_at=>[ts(field.updated_at), ts(field_new.updated_at)]
    }
    event_params = event_args(field, :update, model_changes)
    assert_equal job[:args][1].slice(*event_params.keys), event_params    
    payload = field_new.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field_new))
    # Discarding changes
    field_new.update_attributes(
      {
        :label=> field.label,
        :label_in_portal=> field.label_in_portal,
        :required_for_closure => false,
        :visible_in_portal=> false,
        :editable_in_portal => false
      })
  end

  def test_edit_agent_field
    field = @account.ticket_fields.find_by_name('agent')
    field_updated = field.updated_at
    put :update, :jsonData => @default_fields.push({
                                                    :field_type => field.field_type,
                                                    :name => field.name,
                                                    :label => "Agent Name",
                                                    :label_in_portal => "Agent Name",
                                                    :description => "Agent",
                                                    :active => true,
                                                    :required => true,
                                                    :required_for_closure => true,
                                                    :visible_in_portal => true,
                                                    :editable_in_portal => true,
                                                    :required_in_portal => false,
                                                    :id => field.id,
                                                    :choices => [],
                                                    :levels => [],
                                                    :action => "edit"}).to_json
    assert_response :redirect
    field_new = @account.ticket_fields.find_by_name('agent')
    # assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 1
    job = CentralPublishWorker::TicketFieldWorker.jobs.first.deep_symbolize_keys
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:update)
    model_changes = {
      :label=>[field.label, field_new.label],
      :label_in_portal=>[field.label_in_portal, field_new.label_in_portal],
      :required => [false, true],
      :required_for_closure => [false, true],
      :editable_in_portal=>[false, true],
      :updated_at=>[ts(field.updated_at), ts(field_new.updated_at)]
    }
    event_params = event_args(field, :update, model_changes)
    assert_equal job[:args][1].slice(*event_params.keys), event_params    
    payload = field_new.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field_new))
    # Discarding changes
    field_new.update_attributes(
      {
        :label=> field.label,
        :label_in_portal=> field.label_in_portal,
        :required_for_closure => false,
        :required => false,
        :editable_in_portal => false
      })
  end

  def test_edit_group_field
    field = @account.ticket_fields.find_by_name('group')
    put :update, :jsonData => @default_fields.push({
                                                    :field_type => field.field_type,
                                                    :name => field.name,
                                                    :label => "Group Name",
                                                    :label_in_portal => "Group Name",
                                                    :description => "Ticket group",
                                                    :active => true,
                                                    :required => true,
                                                    :required_for_closure => true,
                                                    :visible_in_portal => true,
                                                    :editable_in_portal => true,
                                                    :required_in_portal => false,
                                                    :id => field.id,
                                                    :choices => [],
                                                    :levels => [],
                                                    :action => "edit"}).to_json
    assert_response :redirect
    field_new = @account.ticket_fields.find_by_name('group')
    # assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 1
    job = CentralPublishWorker::TicketFieldWorker.jobs.first.deep_symbolize_keys
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:update)
    model_changes = {
      :label=>[field.label, field_new.label],
      :label_in_portal=>[field.label_in_portal, field_new.label_in_portal],
      :required=>[false, true],
      :required_for_closure=>[false, true],
      :visible_in_portal=>[false, true],
      :editable_in_portal=>[false, true],
      :updated_at=>[ts(field.updated_at), ts(field_new.updated_at)]
    }
    event_params = event_args(field, :update, model_changes)
    assert_equal job[:args][1].slice(*event_params.keys), event_params    
    payload = field_new.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field_new))
    # Discarding changes
    field_new.update_attributes(
      {
        :label=> field.label,
        :label_in_portal=> field.label_in_portal,
        :required=> false,
        :required_for_closure => false,
        :visible_in_portal=> false,
        :editable_in_portal => false
      })
  end

  def test_edit_product_field
    field = @account.ticket_fields.find_by_name('product')
    put :update, :jsonData => @default_fields.push({
                                                    :field_type => field.field_type,
                                                    :name => field.name,
                                                    :label => "Product Name",
                                                    :label_in_portal => "Product Name",
                                                    :description => "Select the product, the ticket belongs to.",
                                                    :active => true,
                                                    :required => true,
                                                    :required_for_closure => true,
                                                    :visible_in_portal => true,
                                                    :editable_in_portal => true,
                                                    :required_in_portal => false,
                                                    :id => field.id,
                                                    :choices => [],
                                                    :levels => [],
                                                    :action => "edit"}).to_json
    assert_response :redirect
    field_new = @account.ticket_fields.find_by_name('product')
    # assert_equal CentralPublishWorker::TicketFieldWorker.jobs.size, 1
    job = CentralPublishWorker::TicketFieldWorker.jobs.first.deep_symbolize_keys
    assert_equal job[:class], job_type
    assert_equal job.slice(*job_args.keys), job_args
    assert_equal job[:args][0], event_type(:update)
    model_changes = {
      :label=>[field.label, field_new.label],
      :label_in_portal=>[field.label_in_portal, field_new.label_in_portal],
      :required=>[false, true],
      :required_for_closure=>[false, true],
      :updated_at=>[ts(field.updated_at), ts(field_new.updated_at)]
    }
    event_params = event_args(field, :update, model_changes)
    assert_equal job[:args][1].slice(*event_params.keys), event_params    
    payload = field_new.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field_new))
    # Discarding changes
    field_new.update_attributes(
      {
        :label=> field.label,
        :label_in_portal=> field.label_in_portal,
        :required=> false,
        :required_for_closure => false
      })
  end

  # def test_delete_a_section_along_with_section_fields
  #   flexifield_def_id = @account.flexi_field_defs.find_by_name("Ticket_#{@account.id}").id
  #   ff_def_entry = FactoryGirl.build(:flexifield_def_entry, 
  #                                    :flexifield_def_id => flexifield_def_id,
  #                                    :flexifield_alias => "section_field_2_#{@account.id}",
  #                                    :flexifield_name => "ff_text09",
  #                                    :account_id => @account.id)
  #   ff_def_entry.save
  #   new_field = FactoryGirl.build(:ticket_field, :account_id => @account.id,
  #                                    :name => "section_field_2_#{@account.id}",
  #                                    :label => "Section Field 2",
  #                                    :label_in_portal => "Section Field 2",
  #                                    :field_options => {:section => true},
  #                                    :flexifield_def_entry_id => ff_def_entry.id)
  #   new_field.save

  #   parent_ticket_field = @account.ticket_fields.find_by_field_type("default_ticket_type")
  #   pl_value_id = parent_ticket_field.picklist_values.create(:value => Faker::Lorem.characters(6)).id
  #   section = FactoryGirl.build(:section, :label => "Section 2", :account_id => @account.id)
  #   section.section_picklist_mappings.build(:picklist_value_id => pl_value_id)
  #   section.section_fields.build(:ticket_field_id => new_field.id,
  #                                :parent_ticket_field_id => parent_ticket_field.id, 
  #                                :position => 1)
  #   section.save

  #   put :update, :jsonData => @default_fields.push({:id => new_field.id,
  #                                                   :type => "paragraph",
  #                                                   :field_type => "custom_paragraph",
  #                                                   :label => "Section Field 2",
  #                                                   :label_in_portal => "Section Field 2",
  #                                                   :description => "",
  #                                                   :active => true,
  #                                                   :required => false,
  #                                                   :required_for_closure => false,
  #                                                   :visible_in_portal => true,
  #                                                   :editable_in_portal => true,
  #                                                   :required_in_portal => false,
  #                                                   :field_options => {:section => true},
  #                                                   :choices => [],
  #                                                   :levels => [],
  #                                                   :action => "delete"}).to_json,
  #               :jsonSectionData => [{
  #                                       :id => section.id,
  #                                       :label => "Section 2", 
  #                                       :picklist_ids => [{ "picklist_value_id" => pl_value_id }], 
  #                                       :action => "delete"
  #                                   }].to_json
  #   # @account.ticket_fields.find_by_label("Section Field 2").should be_nil
  #   # @account.sections.find_by_label("Section 2").should be_nil
  #   # @account.section_fields.find_by_ticket_field_id(new_field.id).should be_nil
  # end

  # def test_move_a_section_field_from_one_section_to_another
  #   flexifield_def_id = @account.flexi_field_defs.find_by_name("Ticket_#{@account.id}").id
  #   ff_def_entry = FactoryGirl.build(:flexifield_def_entry, 
  #                                    :flexifield_def_id => flexifield_def_id,
  #                                    :flexifield_alias => "section_field_2_#{@account.id}",
  #                                    :flexifield_name => "ff_text09",
  #                                    :account_id => @account.id)
  #   ff_def_entry.save
  #   new_field = FactoryGirl.build(:ticket_field, :account_id => @account.id,
  #                                    :name => "section_field_2_#{@account.id}",
  #                                    :label => "Section Field 2",
  #                                    :label_in_portal => "Section Field 2",
  #                                    :field_options => {:section => true},
  #                                    :flexifield_def_entry_id => ff_def_entry.id)
  #   new_field.save

  #   parent_ticket_field = @account.ticket_fields.find_by_field_type("default_ticket_type")
  #   pl_value_id = parent_ticket_field.picklist_values.create(:value => Faker::Lorem.characters(6)).id
  #   new_pl_value_id = parent_ticket_field.picklist_values.create(:value => Faker::Lorem.characters(6)).id
  #   section = FactoryGirl.build(:section, :label => "Section 3", :account_id => @account.id)
  #   section.section_picklist_mappings.build(:picklist_value_id => pl_value_id)
  #   section.section_fields.build(:ticket_field_id => new_field.id,
  #                                :parent_ticket_field_id => parent_ticket_field.id, 
  #                                :position => 1)
  #   section.save
  #   section_field = section.section_fields.first
  #   section_pl_mapping = section.section_picklist_mappings.first

  #   put :update, :jsonData => @default_fields.push({:id => new_field.id,
  #                                                   :type => "paragraph",
  #                                                   :field_type => "custom_paragraph",
  #                                                   :label => "Section Field 2",
  #                                                   :label_in_portal => "Section Field 2",
  #                                                   :description => "",
  #                                                   :active => true,
  #                                                   :required => false,
  #                                                   :required_for_closure => false,
  #                                                   :visible_in_portal => true,
  #                                                   :editable_in_portal => true,
  #                                                   :required_in_portal => false,
  #                                                   :field_options => {:section => true},
  #                                                   :choices => [],
  #                                                   :levels => [],
  #                                                   :action => "edit"}).to_json,
  #               :jsonSectionData => [{:id => section.id, 
  #                                     :label => "Section 3", 
  #                                     :section_fields => [{
  #                                       :id => section_field.id, 
  #                                       :position => 1, 
  #                                       :ticket_field_id => new_field.id, 
  #                                       :parent_ticket_field_id => parent_ticket_field.id, 
  #                                       :action => "delete"}], 
  #                                     :picklist_ids => [{
  #                                       :picklist_value_id => pl_value_id}], 
  #                                     :action => "save"
  #                                       }, 

  #                                     {
  #                                       :label => "Section 4", 
  #                                       :picklist_ids => [{
  #                                         :picklist_value_id => new_pl_value_id }], 
  #                                       :action => "save", 
  #                                       :section_fields => [{
  #                                         :position => 1, 
  #                                         :ticket_field_id => new_field.id, 
  #                                         :parent_ticket_field_id => parent_ticket_field.id }]
  #                                     }].to_json
  #   new_section = @account.sections.find_by_label("Section 4")
  #   # new_section.should be_an_instance_of(Helpdesk::Section)
  #   # new_section.section_fields.first.ticket_field_id.should be_eql(new_field.id)
  # end

end
