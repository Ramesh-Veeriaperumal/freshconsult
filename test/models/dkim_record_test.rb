require_relative '../test_helper'
class DkimRecordTest < ActiveSupport::TestCase
  def test_activerecord_scopes
    assert_equal "SELECT `dkim_records`.* FROM `dkim_records`  WHERE (sg_type != 'mail_cname')", DkimRecord.filter_records.to_sql
    assert_equal "SELECT `dkim_records`.* FROM `dkim_records`  WHERE (sg_type in ('dkim','subdomain_spf','mail_server'))", DkimRecord.custom_records.to_sql
    assert_equal "SELECT `dkim_records`.* FROM `dkim_records`  WHERE (sg_type NOT IN ('dkim','subdomain_spf','mail_server'))", DkimRecord.default_records.to_sql
    assert_equal "SELECT `dkim_records`.* FROM `dkim_records`  WHERE `dkim_records`.`customer_record` = 1", DkimRecord.customer_records.to_sql
    assert_equal "SELECT `dkim_records`.* FROM `dkim_records`  WHERE `dkim_records`.`status` = 0", DkimRecord.non_active_records.to_sql
  end
end
