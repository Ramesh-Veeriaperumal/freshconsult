require_relative '../test_helper'
['ticket_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

class PicklistValueTest < ActiveSupport::TestCase
  include TicketFieldsTestHelper

  def test_picklist_id_null_without_feature
    @account.rollback :redis_picklist_id
    ticket_field = create_custom_field_dropdown(Faker::Lorem.word)
    ticket_field.picklist_values.each do |pv|
      assert_nil pv.picklist_id
    end
  ensure
    ticket_field.destroy if ticket_field
  end

  def test_picklist_id_value_with_redis
    skip('skip failing test cases')
    @account.launch :redis_picklist_id
    current_max_picklist_id = @account.picklist_values.maximum(:picklist_id).to_i
    Redis::DisplayIdLua.load_picklist_id_lua_script
    $redis_others.perform_redis_op('del', "PICKLIST_ID:#{@account.id}")
    ticket_field = create_custom_field_dropdown(Faker::Lorem.word)
    ticket_field.picklist_values.reorder(:picklist_id).each do |pv|
      p 'redis'
      current_max_picklist_id += 1
      assert_equal current_max_picklist_id, pv.picklist_id
    end
  ensure
    ticket_field.destroy if ticket_field
    @account.rollback :redis_picklist_id
  end

  def test_picklist_id_value_with_db
    @account.launch :redis_picklist_id
    current_max_picklist_id = @account.picklist_values.maximum(:picklist_id).to_i
    $redis_display_id.perform_redis_op("SCRIPT", :flush)
    ticket_field = create_custom_field_dropdown(Faker::Lorem.word)
    ticket_field.picklist_values.reorder(:picklist_id).each do |pv|
      p 'db'
      current_max_picklist_id += 1
      assert_equal current_max_picklist_id, pv.picklist_id
    end
  ensure
    ticket_field.destroy if ticket_field
    Redis::DisplayIdLua.load_picklist_id_lua_script
    @account.rollback :redis_picklist_id
  end

end
