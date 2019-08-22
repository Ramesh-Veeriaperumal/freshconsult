require_relative '../../unit_test_helper'
require_relative '../../test_helper'

class TextDelimitedTest < ActionView::TestCase
	
  def test_sql_condition_with_hyphenated_dropdown_value
		@filter = Helpdesk::Filters::CustomTicketFilter.new
		@key =  "flexifields.ffs_01"
		@operator = :is_in
		@values =  ["a-1"]
		@container_for = :dropdown
		condition = Wf::FilterCondition.new(@filter ,@key ,@operator ,@container_for, @values)
		output = condition.container.sql_condition
		assert_equal output,[" flexifields.ffs_01 in (?) ",["a-1"]]
	end

	def test_sql_condition_with_two_values
		@filter = Helpdesk::Filters::CustomTicketFilter.new
		@key =  "flexifields.ffs_01"
		@operator = :is_in
		@values =  ["a-1,-1"]
		@container_for = :dropdown
		condition = Wf::FilterCondition.new(@filter ,@key ,@operator ,@container_for, @values)
		output = condition.container.sql_condition
		assert_equal output,[" (flexifields.ffs_01 is NULL or flexifields.ffs_01 in (?)) ", ["a-1"]]
	end

	def test_sql_condition_with_any_as_dropdown_value
		@filter = Helpdesk::Filters::CustomTicketFilter.new
		@key =  "flexifields.ffs_01"
		@operator = :is_in
		@values =  ["-1"]
		@container_for = :dropdown
		condition = Wf::FilterCondition.new(@filter ,@key ,@operator ,@container_for, @values)
		output = condition.container.sql_condition
		assert_equal output,[" (flexifields.ffs_01 is NULL) "]
	end

end
