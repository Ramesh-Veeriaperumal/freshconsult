if Rails.env.test?
  FactoryGirl.define do
    factory :forum_category  do
      sequence(:name) { |n| "Test Category #{n}"}
      sequence(:description) { |n| "This is a test category #{n}."}
    end


    factory :forum do
      sequence(:name) { |n| "Test Forum #{n}"}
      sequence(:description) { |n| "This is a test forum #{n}."}
      forum_visibility  1
    end


    factory :topic do
      sequence(:title) { |n| "Test Topic #{n}"}
    end

    factory :post do
      sequence(:body_html) { |n| "<p>This is a new post #{n}.</p>"}
    end

    factory :ticket_topic do
    end

    factory :monitorship do
    end
  end
end