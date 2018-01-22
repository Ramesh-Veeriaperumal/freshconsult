if Rails.env.test?
  FactoryGirl.define do
    factory :bot, class: Bot do
      name 'Test bot'
    end
  end
end
