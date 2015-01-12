if Rails.env.test?
  FactoryGirl.define do
    factory :freshfone_call, :class => Freshfone::Call do |f|
      call_sid "CA2db76c748cb6f081853f80dace462a04"
      call_duration "59"
      recording_url 'https://api.twilio.com/2010-04-01/Accounts/AC54ddcb0256672a9391007d423c4e9ab5/Recordings/RE83efe5492ec9922301e052fdcf0b15c9.mp3'
      call_status 1
      call_type 1
      dial_call_sid "CA2db76c748cb6f081853f80dace462a04"
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