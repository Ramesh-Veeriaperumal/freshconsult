module FreshcallerSpecHelper
  def create_customer_with_phone
    customer = FactoryGirl.build(
      :user,
      account: @account,
      email: Faker::Internet.email,
      user_role: Hash[*User::USER_ROLES.map { |i| [i[0], i[2]] }.flatten][:customer],
      phone: Faker::PhoneNumber.phone_number
    )
    customer.save
    customer
  end

  def create_test_freshcaller_account
    freshcaller_account = @account.build_freshcaller_account(
      freshcaller_account_id: 1,
      domain: 'localhost.test.domain'
    )
    freshcaller_account.save
    @account.make_current.add_feature :freshcaller
    @account.reload
  end
end
