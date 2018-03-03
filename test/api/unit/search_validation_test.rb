require_relative '../unit_test_helper'

class SearchValidationTest < ActionView::TestCase

  def test_valid
    User.first.make_current
    params = {:term => 'test', :limit => 3, :templates => ['agentSpotlightTicket'], :context => 'spotlight'}
    search_validation = SearchValidation.new(params)
    assert search_validation.valid?
    
  end

  def test_invalid_template_data_type
    User.first.make_current
    params = {:term => 'test', :limit => 3, :templates => 'agentSpotlightTicket', :context => 'spotlight'}
    search_validation = SearchValidation.new(params)
    refute search_validation.valid?
    error = search_validation.errors.full_messages
    assert error.include?('Templates datatype_mismatch')
  end

  def test_invalid_template_type
    User.first.make_current
    params = {:term => 'test', :limit => 3, :templates => ['agentSpotlightticket'], :context => 'spotlight'}
    search_validation = SearchValidation.new(params)
    search_validation.valid?
    error = search_validation.errors.full_messages
    assert error.include?('Templates not_included')
  end

  def test_without_templates
    User.first.make_current
    params = {:term => 'test', :limit => 3, :context => 'spotlight'}
    search_validation = SearchValidation.new(params)
    search_validation.valid?
    error = search_validation.errors.full_messages
    assert error.include?('Templates datatype_mismatch')
  end

  def test_invalid_context
    User.first.make_current
    params = {:term => 'test', :limit => 3, :templates => ['agentSpotlightTicket'], :context => Faker::Lorem.word}
    search_validation = SearchValidation.new(params)
    search_validation.valid?
    error = search_validation.errors.full_messages
    assert error.include?('Context not_included')
  end

  # Commented this for a hack, can use when forums feature has been migrated to bitmap
  # def test_without_forums_feature
  #   account = Account.first.make_current
  #   User.first.make_current
  #   f = account.features.forums
  #   account.features.forums.destroy
  #   account.reload
  #   params = {:term => 'test', :limit => 3, :templates => ['agentSpotlightTopic'], :context => 'spotlight'}
  #   search_validation = SearchValidation.new(params)
  #   search_validation.valid?
  #   error = search_validation.errors.full_messages
  #   assert error.include?('Templates require_feature')
  # ensure
  #   account.features.forums.create unless f.new_record? 
  # end

  def test_without_solutions_privilege
    User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
    User.first.make_current
    params = {:term => 'test', :limit => 3, :templates => ['agentSpotlightSolution'], :context => 'spotlight'}
    search_validation = SearchValidation.new(params)
    search_validation.valid?
    error = search_validation.errors.full_messages
    assert error.include?('Templates access_denied')
  ensure
    User.unstub(:current)
  end

  def test_without_term
    User.first.make_current
    params = {:limit => 3, :templates => ['agentSpotlightTicket'], :context => 'spotlight'}
    search_validation = SearchValidation.new(params)
    search_validation.valid?
    error = search_validation.errors.full_messages
    assert error.include?('Term datatype_mismatch')
  end

  def test_with_empty_term
    User.first.make_current
    params = {term: '', :limit => 3, :templates => ['agentSpotlightTicket'], :context => 'spotlight'}
    search_validation = SearchValidation.new(params)
    search_validation.valid?
    error = search_validation.errors.full_messages
    assert error.include?('Term blank')
  end

  def test_with_higher_limit
    User.first.make_current
    params = {term: Faker::Lorem.word, :limit => 50, :templates => ['agentSpotlightTicket'], :context => 'spotlight'}
    search_validation = SearchValidation.new(params)
    search_validation.valid?
    error = search_validation.errors.full_messages
    assert error.include?('Limit limit_invalid')
  end

  def test_with_non_integer_limit
    User.first.make_current
    params = {term: Faker::Lorem.word, :limit => '50', :templates => ['agentSpotlightTicket'], :context => 'spotlight'}
    search_validation = SearchValidation.new(params)
    search_validation.valid?
    error = search_validation.errors.full_messages
    assert error.include?('Limit limit_invalid')
  end

end
