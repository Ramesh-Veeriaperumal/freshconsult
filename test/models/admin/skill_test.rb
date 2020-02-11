require_relative '../test_helper'
class Admin::SkillTest < ActiveSupport::TestCase
  def test_activerecord_scopes
    Account.reset_current_account
    assert_equal 'SELECT skills.id, skills.name FROM `skills` ', Admin::Skill.trimmed.to_sql
  end
end
