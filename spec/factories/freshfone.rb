if Rails.env.test?
  Factory.define :freshfone_call, :class => Freshfone::Call do |f|
    f.call_sid "CA2db76c748cb6f081853f80dace462a04"
    f.call_duration "59"
    f.recording_url
    f.call_status 1
    f.call_type 1
    f.dial_call_sid "CA2db76c748cb6f081853f80dace462a04"
  end

  Factory.define :freshfone_account, :class => Freshfone::Account do |f|
    f.twilio_subaccount_id "AC9fa514fa8c52a3863a76e2d76efa2b8e"
    f.twilio_subaccount_token "58aacda85de70e5cf4f0ba4ea50d78ab"
    f.twilio_application_id "AP932260611f4e4830af04e4e3fed66276"
  end

  Factory.define :freshfone_number, :class => Freshfone::Number do |f|
    f.number "+12407433321"
    f.region  "Pennsylvania"
    f.country "US"
    f.number_type 1
    f.queue_wait_time 2
    f.max_queue_length 3
  end
end