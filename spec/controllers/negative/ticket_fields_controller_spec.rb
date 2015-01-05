require 'spec_helper'
include TicketFieldsHelper

describe TicketFieldsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    @default_fields = ticket_field_hash(@account.ticket_fields, @account)
    @default_fields.map{|f_d| f_d.delete(:level_three_present)}
    login_admin
  end

  it "should not allow duplicate custom field" do
    @request.env['HTTP_REFERER'] = '/ticket_fields'
    label = 'Paragraph'
    (1..2).each do |num_field|
      @default_fields.push({:type => "paragraph", 
                            :field_type => "custom_paragraph", 
                            :label => label, 
                            :label_in_portal => label, 
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
                            :action => "create"})
    end
    put :update, :jsonData => @default_fields.to_json
    flash[:error].should eql " #{label} : has already been taken "
  end

  it "should throw not allowed to create more than 10 checkbox error" do
    @request.env['HTTP_REFERER'] = '/ticket_fields'
    (1..11).each do |num_field|
      @default_fields.push({:type => "checkbox", 
                            :field_type => "custom_checkbox", 
                            :label => "CB_#{num_field}", 
                            :label_in_portal => "CB_#{num_field}", 
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
                            :action => "create"})
    end
    put :update, :jsonData => @default_fields.to_json
    flash[:error].should eql 'You are not allowed to create more than 10 checkbox fields.'
  end
  
end