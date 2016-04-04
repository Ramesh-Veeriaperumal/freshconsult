require 'spec_helper'

TEST_CASES =  { :escape_markup_language => { :input => "<>'&\"", :output => "&lt;&gt;&#39;&amp;&quot;" },
                :render_json_string_without_quotes => { :input => "{\"success\":1,\"return\":{\"29777582\":{\"pair\":\"ltc_rur\",\"type\":\"sell\",\"amount\":1.0,\"rate\":88.99999,\"timestamp_created\":1375718423,\"status\":0},\"29777557\":{\"pair\":\"ltc_rur\",\"type\":\"sell\",\"amount\":1.0,\"rate\":89.0,\"timestamp_created\":1,\"status\":0},\"29777530\":{\"pair\":\"ltc_rur\",\"type\":\"sell\",\"amount\":0.27066199,\"rate\":90.0,\"timestamp_created\":1,\"status\":0}}}", 
                                                        :output => "{\\\"success\\\":1,\\\"return\\\":{\\\"29777582\\\":{\\\"pair\\\":\\\"ltc_rur\\\",\\\"type\\\":\\\"sell\\\",\\\"amount\\\":1.0,\\\"rate\\\":88.99999,\\\"timestamp_created\\\":1375718423,\\\"status\\\":0},\\\"29777557\\\":{\\\"pair\\\":\\\"ltc_rur\\\",\\\"type\\\":\\\"sell\\\",\\\"amount\\\":1.0,\\\"rate\\\":89.0,\\\"timestamp_created\\\":1,\\\"status\\\":0},\\\"29777530\\\":{\\\"pair\\\":\\\"ltc_rur\\\",\\\"type\\\":\\\"sell\\\",\\\"amount\\\":0.27066199,\\\"rate\\\":90.0,\\\"timestamp_created\\\":1,\\\"status\\\":0}}}" },
                :do_percent_encoding => { :input => "name=rachel das&!#$&'()*+,/:=?@[]job=developer%-.<>\^_`{|}~", :output => "name=rachel%20das&!'()*+,/:=?@[]job=developer%25-.%3C%3E%5E_%60%7B%7C%7D~" }
              }
RSpec.configure do |c|
  c.include Va::Webhook::HelperMethods
end

RSpec.describe Va::Webhook::HelperMethods do

  TEST_CASES.each do |method, test_case|
    it "should #{method.to_s.humanize.downcase}" do
      input = test_case[:input]
      output = test_case[:output]
      send(method, input).should be_eql(output)
    end
  end

end