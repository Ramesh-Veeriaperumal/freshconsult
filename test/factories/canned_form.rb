if Rails.env.test?
  FactoryGirl.define do
    factory :canned_form, class: Admin::CannedForm do
      name 'Test Canned Form'
    end
  end
end
