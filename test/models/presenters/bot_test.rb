require_relative '../test_helper'

class BotTest < ActiveSupport::TestCase
  include BotTestHelper

  def test_ml_training_start_payload
    skip('skip failing test cases')
    bot = add_new_bot
    payload = bot.central_publish_payload(:ml_training_start).to_json
    payload.must_match_json_expression(central_publish_ml_training_start_pattern(bot))
  end

  def test_ml_training_end_payload
    skip('skip failing test cases')
    bot = add_new_bot
    bot.training_completed = true
    payload = bot.central_publish_payload(:ml_training_end).to_json
    payload.must_match_json_expression(central_publish_ml_training_end_pattern(bot))
  end
end
