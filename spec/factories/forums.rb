if Rails.env.test?
  FactoryGirl.define do
    factory :forum_category  do
      name { Faker::Lorem.words.join(' ').capitalize }
      description { Faker::Lorem.sentence }
    end


    factory :forum do
      name { Faker::Lorem.words.join(' ').capitalize }
      description Faker::Lorem.sentence
      forum_visibility  1
    end


    factory :topic do
      title { Faker::Lorem.sentence }
    end

    factory :post do
      body_html { "<p>#{Faker::Lorem.paragraph}</p>" }
    end

    factory :ticket_topic do
    end

    factory :monitorship do
    end
  end

  FactoryGirl.define do
    factory :vote, :class => Vote do |v|
    end
  end

end