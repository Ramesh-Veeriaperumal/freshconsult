require_relative '../unit_test_helper'
require_relative '../helpers/test_case_methods'
require_relative '../helpers/query_hash_helper'
require_relative '../helpers/ticket_fields_test_helper'

class QueryHashTest < ActionView::TestCase

  include QueryHashHelper
  include TicketFieldsTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.first.make_current
    User.first.make_current
    @custom_field = create_custom_field_dropdown
    @filter = create_filter(@custom_field)
    @input_with_custom_field = QueryHash.new(@filter.query_hash).to_json
  end

  # Terms
  # Two formats : system format & output format
  # query_hash refers to the original query conditions stored in db
  # Assume Q is the query_hash of the a filter
  # Adding prefix S means system transformation
  # Adding prefix O means output transformation

  # Test cases
  # Lossless transformation tests
  # 1. Q should equal SQ
  # 2. Q should equal SOQ
  # 3. OQ should equal OOQ
  # Other tests
  # 4. Checking the structure of the system queries
  # 5. Checking the structure of the output queries
  # 6. Output shouldn't have spam & deleted column related query conditions
  # 7. Created at transformation
  #    a. perform lossless transformation test
  #    b. check the input & response structure
  #    c. check the date transformation separately
  # 8. Should not output the filter conditions with deleted custom fields
  #    Deleted custom field related query conditions should not appear in the output
  # 9. Check whether a invalid custom field related condition is not being taken

  def test_system_transformation_equality
    q = @filter.query_hash
    aq = QueryHash.new(q)
    sq = aq.to_system_format
    assert_equal(q, sq)
  end

  def test_system_retransformation_equality
    q = @filter.query_hash
    aq = QueryHash.new(q)
    oq = aq.to_json
    bq = QueryHash.new(oq)
    soq = bq.to_system_format
    assert_equal(q, soq)
  end

  def test_system_output_transformation_equality
    q = @filter.query_hash
    aq = QueryHash.new(q)
    oq = aq.to_json
    bq = QueryHash.new(oq)
    ooq = bq.to_json
    assert_equal(oq, ooq)
  end

  def test_system_format_queries
    q = @filter.query_hash
    aq = QueryHash.new(q)
    bq = QueryHash.new(aq.to_json)
    bq.to_system_format.each do |query|
      system_format_query_check(query)
    end
  end

  def test_output_format_queries
    q = @filter.query_hash
    aq = QueryHash.new(q)
    aq.to_json.each do |query|
      output_format_query_check(query)
    end
  end

  def test_remove_spam_and_deleted_conditions
    q = @filter.query_hash
    aq = QueryHash.new(q)
    oq = aq.to_json
    assert not_contain_spam_deleted(oq)
  end

  def test_created_at_lossless_transformation
    q = sample_created_at_input_condition
    aq = QueryHash.new(q)
    sq = aq.to_system_format
    oq = aq.to_json
    bq = QueryHash.new(oq)
    soq = bq.to_system_format
    ooq = bq.to_json

    assert_equal(q, oq)
    assert_equal(q, ooq)
    assert_equal(sq, soq)
  end

  def test_created_at_response_structure
    q = sample_created_at_input_condition
    aq = QueryHash.new(q)
    sq = aq.to_system_format
    oq = aq.to_json
    match_custom_json(sq, system_query_created_at_pattern)
    match_custom_json(oq, response_query_created_at_pattern)
  end

  def test_created_at_transformed_values
    from_time = (Time.zone.now - 1.month)
    to_time = Time.zone.now
    q = sample_created_at_input_condition({ from: from_time.iso8601, to: to_time.iso8601 })
    aq = QueryHash.new(q)
    sq = aq.to_system_format
    oq = aq.to_json
    formatted_time = "#{from_time.strftime('%d %b %Y %T')} - #{to_time.strftime('%d %b %Y %T')}"
    match_custom_json(sq, system_query_created_at_pattern(time: formatted_time))
    match_custom_json(oq, response_query_created_at_pattern({ from: from_time.iso8601, to: to_time.iso8601 }))
  end

  def test_remove_from_output_deleted_custom_fields
    q = @filter.query_hash
    aq = QueryHash.new(q)
    oq = aq.to_json
    assert contains_custom_field_condition(oq, @custom_field)
    @custom_field.destroy
    aq = QueryHash.new(q)
    oq = aq.to_json
    assert !contains_custom_field_condition(oq, @custom_field)
  end

  def test_remove_deleted_custom_fields_from_input
    aq = QueryHash.new(@input_with_custom_field)
    oq = aq.to_json
    sq = aq.to_system_format
    assert !contains_custom_field_condition(sq, @custom_field)
    assert !contains_custom_field_condition(oq, @custom_field, false)
  end

  def test_fr_due_by_lossless_transformation
    q = sample_fr_due_by_input_condition
    aq = QueryHash.new(q)
    sq = aq.to_system_format
    oq = aq.to_json
    bq = QueryHash.new(oq)
    soq = bq.to_system_format
    ooq = bq.to_json

    assert_equal(q, oq)
    assert_equal(q, ooq)
    assert_equal(sq, soq)
  end

end
