if Rails.env.test?
  FactoryGirl.define do
    factory :user do
      sequence(:name) { |n| "Foo#{n}" }
      time_zone "Chennai"
      active 1
      user_role 1
      phone Faker::PhoneNumber.phone_number
      mobile Faker::PhoneNumber.phone_number
      crypted_password "5ceb256c792bcf9dab05c8a00775fc13b42a6abd516f130acd76ab81af046d49a1fc5062bec4f27b77580348de6d8c510c7ff6b29f720694ff39a5bfd69c604d"
      sequence(:single_access_token) { |n| "#{Faker::Lorem.characters(19)}#{n}" }
      password_salt "Hd8iUst0Jr5TWnulZhgf"
      sequence(:persistence_token) { |n| "#{Faker::Lorem.characters(127)}#{n}" }
      delta 1
      language "en"
    end

    factory :company, :class => Customer do
      sequence(:name) { |n| "Foo#{n}" }
      description {Faker::Lorem.sentence(2)}
      note {Faker::Lorem.sentence(2)}
      domains {Faker::Internet.domain_name}
    end
    
    factory :customer do |p|
      p.account_id 1
      p.name  { Forgery(:lorem_ipsum).words(1) }
    end
    
  end
end