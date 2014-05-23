require 'spec_helper'
include TicketFieldsHelper

describe TicketFieldsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
    @default_fields = ticket_field_hash(@account.ticket_fields, @account)
    @default_fields.delete(:level_three_present)
  end

  before(:each) do
    @request.host = @account.full_domain
    log_in(@user)
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

  it "should edit a custom field" do
    flexifield_def_entry = Factory.build( :flexifield_def_entry, 
                                          :flexifield_def_id => @account.flexi_field_defs.find_by_module("Ticket").id,
                                          :flexifield_alias => "solution_#{@account.id}",
                                          :flexifield_name => "ff_text02",
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

  it "should delete a custom field" do
    flexifield_def_entry = Factory.build( :flexifield_def_entry, 
                                          :flexifield_def_id => @account.flexi_field_defs.find_by_module("Ticket").id,
                                          :flexifield_alias => "incident_#{@account.id}",
                                          :flexifield_name => "ff_text03",
                                          :account_id => @account.id)
    flexifield_def_entry.save
    custom_field = Factory.build( :ticket_field, :account_id => @account.id,
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
end