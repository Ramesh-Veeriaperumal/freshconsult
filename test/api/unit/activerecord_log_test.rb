require_relative '../unit_test_helper'
class ActiveRecord::LogSubscriberTest < ActiveSupport::TestCase
  include Redis::OthersRedis
  include Cache::LocalCache

  def setup
    add_member_to_redis_set('ACTIVE_RECORD_LOG', 1)
  end

  def teardown
    remove_member_from_redis_set('ACTIVE_RECORD_LOG', 1)
  end

  def test_to_hide_single_access_sensitivedata_in_update_query
    input_sql = "UPDATE `users` SET `single_access_token` = #{Faker::Lorem.characters(10)}, `text_uc01` = '--- \n:agent_preferences: \n  :falcon_ui: true\n  :freshchat_token: fdf4ce52-a509-4bf6-a92f-fb1276198aa7\n' WHERE `users`.`id` = 11000000268145 AND `users`.`account_id` = 1179979"
    output_sql = "UPDATE `users` SET `single_access_token` = [FILTERED], `text_uc01` = '--- \n:agent_preferences: \n  :falcon_ui: true\n  :freshchat_token: fdf4ce52-a509-4bf6-a92f-fb1276198aa7\n' WHERE `users`.`id` = 11000000268145 AND `users`.`account_id` = 1179979"
    verify_filtering(input_sql, output_sql)
  end

  def test_to_hide_sensitive_data_in_update_query_case_1
    input_sql = "UPDATE `users` SET `single_access_token` = #{Faker::Lorem.characters(10)}, `column_2` = '234 = 235' WHERE `users`.`id` = 11000000268145 AND `users`.`account_id` = 1179979"
    output_sql = "UPDATE `users` SET `single_access_token` = [FILTERED], `column_2` = '234 = 235' WHERE `users`.`id` = 11000000268145 AND `users`.`account_id` = 1179979"
    verify_filtering(input_sql, output_sql)
  end

  def test_to_hide_sensitive_data_in_update_query_case_2
    input_sql = "UPDATE `users` SET `single_access_token` = #{Faker::Lorem.characters(10)}, `column_2` = '234, 235' WHERE `users`.`id` = 11000000268145 AND `users`.`account_id` = 1179979"
    output_sql = "UPDATE `users` SET `single_access_token` = [FILTERED], `column_2` = '234, 235' WHERE `users`.`id` = 11000000268145 AND `users`.`account_id` = 1179979"
    verify_filtering(input_sql, output_sql)
  end

  def test_to_hide_sensitive_data_in_update_query_case_3
    input_sql = "UPDATE `users` SET `single_access_token` = #{Faker::Lorem.characters(10)}, `column_2` = '234, 2 = 35' WHERE `users`.`id` = 11000000268145 AND `users`.`account_id` = 1179979"
    output_sql = "UPDATE `users` SET `single_access_token` = [FILTERED], `column_2` = '234, 2 = 35' WHERE `users`.`id` = 11000000268145 AND `users`.`account_id` = 1179979"
    verify_filtering(input_sql, output_sql)
  end

  def test_to_hide_sensitive_data_in_update_query_case_4
    input_sql = "UPDATE `users` SET `single_access_token` = #{Faker::Lorem.characters(10)}, `column_2` = '234, 2 = 3, 5' WHERE `users`.`id` = 11000000268145 AND `users`.`account_id` = 1179979"
    output_sql = "UPDATE `users` SET `single_access_token` = [FILTERED], `column_2` = '234, 2 = 3, 5' WHERE `users`.`id` = 11000000268145 AND `users`.`account_id` = 1179979"
    verify_filtering(input_sql, output_sql)
  end

  def test_to_hide_sensitive_data_in_update_query_case_5
    input_sql = "UPDATE `users` SET `single_access_token` = #{Faker::Lorem.characters(10)}, `column_2` = '234, 2 = 3\\', 5' WHERE `users`.`id` = 11000000268145 AND `users`.`account_id` = 1179979"
    output_sql = "UPDATE `users` SET `single_access_token` = [FILTERED], `column_2` = '234, 2 = 3\\', 5' WHERE `users`.`id` = 11000000268145 AND `users`.`account_id` = 1179979"
    verify_filtering(input_sql, output_sql)
  end

  private

    def verify_filtering(input_sql, expected_output_sql)
      result = ActiveRecord::LogSubscriber.new.hide_confidential_logs(input_sql)
      assert_equal result, expected_output_sql
    end
end
