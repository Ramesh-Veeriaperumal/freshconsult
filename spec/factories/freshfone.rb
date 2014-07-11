if ENV["RAILS_ENV"] == "test"
  Factory.define :freshfone_call, :class => Freshfone::Call do |f|
    f.call_sid "CA5129fa990bff042e3e83cdd8a53832ef"
    f.call_duration "59"
    f.recording_url
    f.call_status 1
    f.call_type 1
    f.customer_data HashWithIndifferentAccess.new({ :number => "+16617480240",:country => 'US',:state => 'CA',:city => 'BAKERSFIELD' })
    f.dial_call_sid "CA0e2ea89440bf032722ee2b09af410a3e"
    f.customer_number "+16617480240"
  end

  Factory.define :freshfone_account, :class => Freshfone::Account do |f|
    f.twilio_subaccount_id "AC7368db9093a016b0d4e92b1af6453107"
    f.twilio_subaccount_token "1657afcd82d749ca560fd5c0fdfe726e"
    f.twilio_application_id "AP7ebabc7868714420960a2dc8da9de95e"
  end

  Factory.define :freshfone_number, :class => Freshfone::Number do |f|
    f.number "+17274780266"
    f.region  "Pennsylvania"
    f.country "US"
    f.number_type 1
    f.queue_wait_time 2
    f.max_queue_length 3
  end
end