if Rails.env.test?
  Factory.define :user do |f|
    f.sequence(:name) { |n| "Foo#{n}" }
    f.time_zone "Chennai"
    f.active 1
    f.user_role 1
    f.phone Faker::PhoneNumber.phone_number
    f.mobile Faker::PhoneNumber.phone_number
    f.crypted_password "5ceb256c792bcf9dab05c8a00775fc13b42a6abd516f130acd76ab81af046d49a1fc5062bec4f27b77580348de6d8c510c7ff6b29f720694ff39a5bfd69c604d"
    f.sequence(:single_access_token) { |n| "#{Faker::Lorem.characters(19)}#{n}" }
    f.password_salt "Hd8iUst0Jr5TWnulZhgf"
    f.sequence(:persistence_token) { |n| "#{Faker::Lorem.characters(127)}#{n}" }
    f.delta 1
    f.language "en"
  end

  Factory.define :company, :class => Customer do |c|
    c.sequence(:name) { |n| "Company#{n}" }
    c.description {Faker::Lorem.sentence(2)}
    c.note {Faker::Lorem.sentence(2)}
    c.domains {Faker::Internet.domain_name}
  end
end