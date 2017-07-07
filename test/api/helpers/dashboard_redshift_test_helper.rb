module DashboardRedshiftTestHelper

  def dashboard_metrics_data
    [[{"result"=>[{"received_count"=>"13", "resolved_count"=>"3", "resolution_sla_count"=>"3", "first_response_sum"=>"2442", "first_response_count"=>"4", "response_sum"=>"3312", "response_count"=>"5"}], "index"=>0}], 600, dashboard_redshift_dump_time]
  end

  def dashboard_trends_data
    [[{"result"=>[{"range_benchmark"=>"f", "h"=>"18", "received_count"=>"3"}, {"range_benchmark"=>"t", "h"=>"12", "received_count"=>"6"}, {"range_benchmark"=>"t", "h"=>"11", "received_count"=>"3"}, {"range_benchmark"=>"t", "h"=>"13", "received_count"=>"1"}, {"range_benchmark"=>"t", "h"=>"4", "received_count"=>"1"}, {"range_benchmark"=>"f", "h"=>"15", "received_count"=>"6"}, {"range_benchmark"=>"f", "h"=>"14", "received_count"=>"1"}, {"range_benchmark"=>"f", "h"=>"13", "received_count"=>"5"}, {"range_benchmark"=>"f", "h"=>"16", "received_count"=>"5"}, {"range_benchmark"=>"f", "h"=>"19", "received_count"=>"1"}], "index"=>0}], 600, dashboard_redshift_dump_time]
  end

  def dashboard_redshift_failure_data
    [[{:errors=>"We are Sorry. Something went Wrong."}], 12349, dashboard_redshift_dump_time]
  end

  def dashboard_trends_parsed_response
    {:today=>[0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 3, 6, 1, 0, 0, 0, 0, 0, 0, 0, 0], :yesterday=>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 1, 6, 5, 0, 3, 1, 0, 0, 0, 0], :last_dump_time => dashboard_redshift_dump_time}
  end

  def dashboard_metrics_parsed_response
    {:received=>13, :resolved=>3, :first_response=>"10m", :avg_response=>"11m", :sla=>100, :last_dump_time => dashboard_redshift_dump_time}
  end

  def dashboard_redshift_dump_time
    "Wed, 31 May 2017 21:28:04 IST +05:30"
  end

  def dashboard_redshift_current_time
   Time.zone.parse( "Wed, 31 May 2017 21:38:04 IST +05:30")
  end

end