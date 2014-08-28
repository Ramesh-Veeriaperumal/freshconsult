module Wf::FilterHelper

  def before_all
    RSpec.configuration.account = create_test_account
    @user = add_test_agent(@account)
    @user.make_current
  end

  def prep_ticket
    RSpec.configuration.account.ticket_fields_with_nested_fields.custom_fields.each &:destroy # should remove once test cases for custom fields are written
    3.times do # populating objects
      @company = RSpec.configuration.account.customers.create(FactoryGirl.attributes_for(:company))
      @group = RSpec.configuration.account.groups.create(FactoryGirl.attributes_for(:group))
      @requester = RSpec.configuration.account.users.create(FactoryGirl.attributes_for(:user, :email => Faker::Internet.email, :customer_id => @company.id))
      @product = RSpec.configuration.account.products.create(FactoryGirl.attributes_for(:product))
      @tag = RSpec.configuration.account.tags.create(FactoryGirl.attributes_for(:tag))
      @test_agent = add_test_agent(@account)
      @ticket = RSpec.configuration.account.tickets.create(FactoryGirl.attributes_for(:ticket, :requester_id => @requester.id, :responder_id => @test_agent.id, :group_id => @group.id, :product_id => @product.id, :created_at => 4.days.from_now))
      @ticket.tags = [@tag]
      @ticket.due_by = [2.days.ago, 10.minutes.from_now, (8*60 + 10).minutes.from_now, 1.days.from_now].sample #[overdue, due within next 8 hrs, today, tomorrow]
      @ticket.save
    end
  end

end
