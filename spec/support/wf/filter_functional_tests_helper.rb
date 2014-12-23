module Wf::FilterFunctionalTestsHelper

  NESTED_FIELD  = { :field_type=>"nested_field", :label=>Faker::Name.name, :label_in_portal=>"Dependent1", :description=>"", :position=>111, :active=>true, :required=>false, :required_for_closure=>false, :visible_in_portal=>true, :editable_in_portal=>true, :required_in_portal=>false, :field_options=>nil, :type=>"dropdown", :choices=>[["category 1", "category 1", [["subcategory 1", "subcategory 1", [["item 1", "item 1"], ["item 2", "item 2"]]], ["subcategory 2", "subcategory 2", [["item 1", "item 1"], ["item 2", "item 2"]]], ["subcategory 3", "subcategory 3", []]]], ["category 2", "category 2", [["subcategory 1", "subcategory 1", [["item 1", "item 1"], ["item 2", "item 2"]]]]]], 
                    :levels=>[{"id"=>3, "label"=>Faker::Name.name, "label_in_portal"=>"Dependent2", "description"=>"", "level"=>2, "position"=>112, "type"=>"dropdown"}, {"id"=>4, "label"=>Faker::Name.name, "label_in_portal"=>"Dependent3", "description"=>"", "level"=>3, "position"=>113, "type"=>"dropdown"}] }
  DROPDOWN  = { :field_type=>"custom_dropdown", :label=>Faker::Name.name, :label_in_portal=>"Dropdown", :description=>"", :position=>115, :active=>true, :required=>false, :required_for_closure=>false, :visible_in_portal=>true, :editable_in_portal=>true, :required_in_portal=>false, :choices=>[["First Choice", "First Choice"], ["Second Choice", "Second Choice"]], :picklist_values_attributes => [{:value => "First Choice"}, {:value => "Second Choice"}], :levels=>nil, :field_options=>nil, :type=>"dropdown"  }

  def before_all
    #@account = create_test_account
    @user = add_test_agent(@account)
    @user.make_current
  end

  def prep_a_ticket
    @company = @account.companies.create(FactoryGirl.attributes_for(:company))
    @group = @account.groups.create(FactoryGirl.attributes_for(:group))
    @requester = @account.users.create(FactoryGirl.attributes_for(:user, :email => Faker::Internet.email, :customer_id => @company.id))
    @product = @account.products.create(FactoryGirl.attributes_for(:product))
    @tag = @account.tags.create(FactoryGirl.attributes_for(:tag))
    @test_agent = add_test_agent(@account)
    @ticket = @account.tickets.create(FactoryGirl.attributes_for(:ticket, :requester_id => @requester.id, :responder_id => @test_agent.id, :group_id => @group.id, :product_id => @product.id, :created_at => 4.days.from_now))
    @ticket.tags = [@tag]
    @ticket.due_by = [2.days.ago, 10.minutes.from_now, (8*60 + 10).minutes.from_now, 1.days.from_now].sample #[overdue, due within next 8 hrs, today, tomorrow]
    populate_custom_fields # for now hardcoding
    @ticket.save
  end
  
  def populate_custom_fields
    populate_dropdown
    populate_nested_field
  end

  def populate_dropdown
    dropdown = @account.ticket_fields.find_by_label(DROPDOWN[:label])
    @ticket.send(:"#{dropdown.name}=", dropdown.choices.first[0])
  end

  def populate_nested_field
    category = @account.ticket_fields.find_by_label(NESTED_FIELD[:label])
    category_option = category.nested_choices.sample
    assign NESTED_FIELD[:label], category_option[0]
    subcategory_option = category_option[2].sample
    return if subcategory_option.nil? # Just one level
    assign NESTED_FIELD[:levels][0][:label], subcategory_option[0]
    item_option = subcategory_option[2].sample
    return if item_option.nil? # Just two levels
    assign NESTED_FIELD[:levels][1][:label], item_option[0]
  end

  def assign label, value
    field = @account.ticket_fields_with_nested_fields.find_by_label(label)
    @ticket.send(:"#{field.name}=", value)
  end

end
