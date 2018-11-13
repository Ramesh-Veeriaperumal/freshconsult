if Rails.env.test?
  FactoryGirl.define do
    factory :bot, class: Bot do
      name 'Test bot'
    end

    factory :bot_feedback, class: Bot::Feedback do
    end
  end
end