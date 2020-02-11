require_relative '../test_helper'
class DkimRecordTest < ActiveSupport::TestCase
  def test_activerecord_scopes
    time = Time.now
    assert_equal "SELECT `day_pass_usages`.* FROM `day_pass_usages`  WHERE `day_pass_usages`.`granted_on` = '#{time.utc.to_s(:db)}'", DayPassUsage.on_the_day(time).to_sql
    assert_equal "SELECT `day_pass_usages`.* FROM `day_pass_usages`  WHERE (granted_on >= '#{(DayPassUsage.start_time - 10.days).utc.to_s(:db)}')", DayPassUsage.latest(10).to_sql
    assert_equal "SELECT `day_pass_usages`.* FROM `day_pass_usages`  WHERE `day_pass_usages`.`user_id` = 1", DayPassUsage.agent_filter(1).to_sql
  end
end
