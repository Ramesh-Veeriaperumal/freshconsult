require 'spec_helper'

CUSTOM_FIELDS = {
  :nested_field => { :field_type=>"nested_field", :label=>"Dependent 1 #{Faker::Name.name}", :label_in_portal=>"Dependent1", :description=>"", :position=>211, :active=>true, :required=>false, :required_for_closure=>false, :visible_in_portal=>true, :editable_in_portal=>true, :required_in_portal=>false, :field_options=>nil, :type=>"dropdown", :choices=>[["category 1", "category 1", [["subcategory 1", "subcategory 1", [["item 1", "item 1"], ["item 2", "item 2"]]], ["subcategory 2", "subcategory 2", [["item 1", "item 1"], ["item 2", "item 2"]]], ["subcategory 3", "subcategory 3", []]]], ["category 2", "category 2", [["subcategory 1", "subcategory 1", [["item 1", "item 1"], ["item 2", "item 2"]]]]]], 
                    :levels=>[{"id"=>3, "label"=>"Dependent 2 #{Faker::Name.name}", "label_in_portal"=>"Dependent2", "description"=>"", "level"=>2, "position"=>212, "type"=>"dropdown"}, {"id"=>4, "label"=>"Dependent 3 #{Faker::Name.name}", "label_in_portal"=>"Dependent3", "description"=>"", "level"=>3, "position"=>113, "type"=>"dropdown"}] },
  :dropdown => { :field_type=>"custom_dropdown", :label=>"Dropdown #{Faker::Name.name}", :label_in_portal=>"Dropdown", :description=>"", :position=>214, :active=>true, :required=>false, :required_for_closure=>false, :visible_in_portal=>true, :editable_in_portal=>true, :required_in_portal=>false, :choices=>[["First Choice", "First Choice"], ["Second Choice", "Second Choice"]], :levels=>nil, :field_options=>nil, :type=>"dropdown" },
  :text => {:type=>"text", :field_type=>"custom_text", :label=>"Single Line Text #{Faker::Name.name}", :label_in_portal=>"Single Line Text", :description=>"", :position=>215, :active=>true, :required=>false, :required_for_closure=>false, :visible_in_portal=>true, :editable_in_portal=>true, :required_in_portal=>false, :id=>nil, :choices=>[], :levels=>[]},
  :number => {:type=>"number", :field_type=>"custom_number", :label=>"Number #{Faker::Name.name}", :label_in_portal=>"Number", :description=>"", :position=>216, :active=>true, :required=>false, :required_for_closure=>false, :visible_in_portal=>true, :editable_in_portal=>true, :required_in_portal=>false, :id=>nil, :choices=>[], :levels=>[]},
  :paragraph => {:type=>"paragraph", :field_type=>"custom_paragraph", :label=>"Paragraph #{Faker::Name.name}", :label_in_portal=>"Paragraph", :description=>"", :position=>217, :active=>true, :required=>false, :required_for_closure=>false, :visible_in_portal=>true, :editable_in_portal=>true, :required_in_portal=>false, :id=>nil, :choices=>[], :levels=>[]},
  :checkbox => {:type=>"checkbox", :field_type=>"custom_checkbox", :label=>"Checkbox #{Faker::Name.name}", :label_in_portal=>"Checkbox", :description=>"", :position=>218, :active=>true, :required=>false, :required_for_closure=>false, :visible_in_portal=>true, :editable_in_portal=>true, :required_in_portal=>false, :id=>nil, :choices=>[], :levels=>[]}
}
  
include Import::CustomField

def create_ticket_custom_fields
  @invalid_fields = []
  CUSTOM_FIELDS.each do |field_type, field_details|
    create_field(field_details.dup, @account)
  end
  if @invalid_fields.present?
    Rails.logger.debug @invalid_fields.inspect
    raise "Error creating ticket fields for Wf::Filter functionality testing
          Invalid Fields #{@invalid_fields.inspect}"
  end
end

def create_essential_variables 
  @flexifield_def = @account.flexi_field_defs.find_by_name("Ticket_#{@account.id}")
  @flexifield_names = @flexifield_def.flexifield_def_entries.map &:flexifield_name
  @flexifield_aliases = @flexifield_def.flexifield_def_entries.map &:flexifield_alias
end

describe FlexifieldDef do

  before(:all) do
    @account.ticket_fields_with_nested_fields.custom_fields.each &:destroy
    create_ticket_custom_fields
  end

  before(:each) do
    create_essential_variables
  end

  it "should convert ff_name to ff_alias" do
    @flexifield_names.map{ |name| @flexifield_def.to_ff_alias(name) }.should eql(@flexifield_aliases)
  end

end

describe FlexifieldDefEntry do

  before(:each) do
    create_essential_variables
  end

  it "should return db_column of the flexifield, if we give it's alias" do
    @flexifield_aliases.map{ |alias_name| FlexifieldDefEntry.ticket_db_column(alias_name) }.should eql(@flexifield_names)
  end

  it "should return the array of custom fields which have the type as dropdown" do
    dropdown_labels = [CUSTOM_FIELDS[:nested_field][:label], CUSTOM_FIELDS[:nested_field][:levels][0][:label], CUSTOM_FIELDS[:nested_field][:levels][1][:label], CUSTOM_FIELDS[:dropdown][:label]]
    dropdown_names = dropdown_labels.map{ |label| field_name(label, @account) }
    dropdown_fieldnames = @flexifield_def.flexifield_def_entries.find_all_by_flexifield_alias(dropdown_names).map(&:flexifield_name)
    FlexifieldDefEntry.dropdown_custom_fields.should eql(dropdown_fieldnames)
  end

end