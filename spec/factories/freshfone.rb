if Rails.env.test?
  FactoryGirl.define do
    factory :freshfone_call, :class => Freshfone::Call do
      call_sid "CA2db76c748cb6f081853f80dace462a04"
      call_duration "59"
      recording_url "http://api.twilio.com/2010-04-01/Accounts/ACcb66690d4a703515a22f3aa080aa782e/Recordings/REc77ce1f6b56d2081e297f79d8b0d3b15"
      call_status 1
      call_type 1
      customer_data HashWithIndifferentAccess.new({ :number => "+16617480240",:country => 'US',:state => 'CA',:city => 'BAKERSFIELD' })
      dial_call_sid "CA2db76c748cb6f081853f80dace462a04"
      customer_number "+16617480240"
    end

    factory :freshfone_account, :class => Freshfone::Account do
      twilio_subaccount_id "AC9fa514fa8c52a3863a76e2d76efa2b8e"
      twilio_subaccount_token "58aacda85de70e5cf4f0ba4ea50d78ab"
      twilio_application_id "AP932260611f4e4830af04e4e3fed66276"
    end

    factory :freshfone_number, :class => Freshfone::Number do
      number "+12407433321"
      region  "Pennsylvania"
      country "US"
      number_type 1
      queue_wait_time 2
      max_queue_length 3
    end
  end
end