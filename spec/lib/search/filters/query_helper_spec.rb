require 'spec_helper'
include Search::Filters::QueryHelper

RSpec.describe Search::Filters::QueryHelper do
  self.use_transactional_fixtures = false
  before(:all) do
    @current_user = [User.current.id.to_s]
    @user_groups  = User.current.agent_groups.select(:group_id).map(&:group_id).map(&:to_s)
  end

  class Wf_Param < Array
    def push_param(condition, operator, value, ff_name = nil)
      if ff_name.nil?
        self.push('condition' => condition, 'operator' => operator, 'value' => value)
      else
        self.push('condition' => condition, 'operator' => operator, 'ff_name' => ff_name.first, 'value' => value)
      end
    end
  end

  def expected_query(outer_must)
    expected = ({ :query => { :filtered => {} }})
    filter_part = { :bool => { :should => [], :must => outer_must, :must_not => []}}
    expected[:query][:filtered].update(:filter => filter_part)

    expected
  end

  it 'should render new and my open tickets' do
    wf_params = Wf_Param.new
    wf_params.push_param('status', 'is_in', 2)
    wf_params.push_param('responder_id', 'is_in', '-1,0')

    actual = es_query(wf_params)

    outer_must = []
    outer_must.push(:terms => { 'status' => ['2'], :_cache => false })
    outer_must.push(:bool => { :should => [{ :missing => { :field => 'responder_id' }},
                                           { :terms => { 'responder_id' => @current_user,
                                                         :_cache => false } }] })

    actual.should eql(expected_query(outer_must))
  end

  it 'should construct bool filter with should, must and must_not' do
    options = { :should => 'sh', :must => %w[a, b], :must_not => 'mn' }
    actual = bool_filter(options)
    expected = { :bool => { :should => 'sh', :must => %w[a, b], :must_not => 'mn' } }

    actual.should eql(expected)
  end

  it 'should construct bool filter with must only' do
    options = { :must => 'a' }
    actual = bool_filter(options)
    expected = { :bool => { :must => 'a' } }
    actual.should eql(expected)
  end

  it 'should construct missing filter' do
    field_name = 'myfield'
    actual = missing_filter(field_name)
    expected = { :missing => { :field => field_name } }
    actual.should eql(expected)
  end

  it 'should construct range filter without caching' do
    field_name = 'myfield'
    range_options = { :gt => 7, :lt => 10 }
    actual = range_filter(field_name, range_options)
    expected = { :range => { field_name => range_options, :_cache => false } }
    actual.should eql(expected)
  end

  it 'should construct terms filter without caching' do
    field_name = 'myfield'
    values = [1 ,2, 3]
    actual = terms_filter(field_name, values)
    expected = { :terms => { field_name => values, :_cache => false } }
    actual.should eql(expected)
  end

  it 'should construct term filter without caching' do
    field_name = 'myfield'
    value = 5
    actual = term_filter(field_name, value)
    expected = { :term => { field_name => value, :_cache => false } }
    actual.should eql(expected)
  end

  it 'should handle current agent scenario' do
    # when there is 0, it shud be replaced with current user's id

    wf_params = Wf_Param.new
    wf_params.push_param('responder_id', 'is_in', '0', 'default')

    actual = es_query(wf_params)

    outer_must = []
    outer_must.push(:terms => {'responder_id' => @current_user , :_cache =>false })

    actual.should eql(expected_query(outer_must))
  end

  it 'should handle unassigned agent scenario' do
    # when there is -1 with someother user id
    # a missing filter shuld be enclosed in should
    # along with a terms filter for the other user id
    # bool filter should be returned

    wf_params = Wf_Param.new
    wf_params.push_param('responder_id', 'is_in', '-1,1', 'default')

    actual = es_query(wf_params)

    outer_must = []
    outer_must.push(:bool => { :should => [{ :missing => { :field => 'responder_id' }},
                                           { :terms => { 'responder_id' => @current_user ,
                                                         :_cache => false } }] })

    actual.should eql(expected_query(outer_must))
  end

  it 'should handle my groups only' do
    wf_params = Wf_Param.new
    wf_params.push_param('group_id', 'is_in', '0', 'default')

    actual = es_query(wf_params)

    outer_must = []
    outer_must.push(:terms => {'group_id' => @user_groups, :_cache =>false })

    actual.should eql(expected_query(outer_must))
  end

  it 'should handle my groups and unassigned group' do
    wf_params = Wf_Param.new
    wf_params.push_param('group_id', 'is_in', '0,-1', 'default')

    actual = es_query(wf_params)

    outer_must = []
    outer_must.push(:bool => { :should => [{ :missing => { :field => 'group_id' }},
                                           { :terms => { 'group_id' => @user_groups,
                                                         :_cache => false } }] })

    expected = expected_query(outer_must)
    actual.should eql(expected)
  end

  it 'should handle unassigned group scenarios' do
    wf_params = Wf_Param.new
    wf_params.push_param('group_id', 'is_in', '-1', 'default')

    actual = es_query(wf_params)

    outer_must = []
    outer_must.push(:bool => { :should => [{ :missing => { :field => 'group_id' }},
                                           { :terms => { 'group_id' => [],
                                                         :_cache => false } }] })

    expected = expected_query(outer_must)
    actual.should eql(expected)
  end

  it 'should handle conditions appropriately' do
    wf_params = Wf_Param.new
    wf_params.push_param('responder_id', 'is_in', '0,-1', 'default')
    wf_params.push_param('group_id', 'is_in', '1,2', 'default')
    wf_params.push_param('created_at', 'is_greater_than', '60', 'default')
    wf_params.push_param('due_by', 'due_by_op', '3', 'default')
    wf_params.push_param('status', 'is_in', '2,5', 'default')
    wf_params.push_param('priority', 'is_in', '1,2,3', 'default')
    wf_params.push_param('ticket_type', 'is_in', 'Incident,Problem,Feature Request', 'default')
    wf_params.push_param('source', 'is_in', '5,6', 'default')

    es_query = es_query(wf_params)

    base_hash = es_query[:query][:filtered][:filter][:bool]
    base_must = base_hash[:must]

    wf_params.each do |hash|
      case hash['condition']
      when 'deleted', 'spam', 'source', 'ticket_type', 'priority', 'status'
        terms_simple = { :terms => { hash['condition'] =>  hash['value'].to_s.split(','),
                         :_cache => false } }
        base_must.should include(terms_simple)
      when 'due_by'
        # tomorrow - others can't be tested - time will vary
        due_by_bool = { :bool => { :should => [], :must => [] } }
        gte_time = Time.zone.now.tomorrow.beginning_of_day.utc.iso8601
        lte_time = Time.zone.now.tomorrow.end_of_day.utc.iso8601
        due_by_bool[:bool][:should].push(:range => { 'due_by' => { :gte => gte_time,
                                                                   :lte => lte_time },
                                                                   :_cache => false })
        due_by_bool[:bool][:must].push(:term => { 'status_stop_sla_timer' => false, :_cache => false })
        due_by_bool[:bool][:must].push(:term => { 'status_deleted'  => false, :_cache => false })
            base_must.should include(due_by_bool)

      when 'group_id'

        group_id_terms = { :terms => { 'group_id' => ['1','2'], :_cache => false } }
        base_must.should include(group_id_terms)

      when 'responder_id'

        # the input value has -1 so bool query;
        # [0,1,-1] => -1 replaced with missing filter,
        # 0 converted to current user id which is 1
        # unique values taken

        responder_id_bool = { :bool => {:should => [ { :missing => { :field => 'responder_id'} },
                                                     { :terms => {'responder_id' => @current_user , 
                                                                  :_cache => false } } ] }}

        base_must.should include(responder_id_bool)
      end
    end
  end

  it 'should handle open tickets in dashboard' do
    wf_params = Wf_Param.new
    wf_params.push_param('status', 'is_in', '2')
    wf_params.push_param('status', 'is_in', '2,3,6,7')
    actual = es_query(wf_params)

    outer_must = []
    outer_must.push(:terms => { 'status' => ['2'], :_cache => false })
    outer_must.push(:terms => { 'status' => ['2', '3', '6', '7'], :_cache => false })

    expected = expected_query(outer_must)
    actual.should eql(expected)
  end

  it 'should handle onhold tickets in dashboard' do
    wf_params = Wf_Param.new
    wf_params.push_param('status', 'is_in', '3,6')
    wf_params.push_param('status', 'is_in', '2,3,6,7')
    actual = es_query(wf_params)

    outer_must = []
    outer_must.push(:terms => { 'status' => ['3', '6'], :_cache => false })
    outer_must.push(:terms => { 'status' => ['2', '3', '6', '7'], :_cache => false })

    expected = expected_query(outer_must)
    actual.should eql(expected)
  end

  it 'should handle due today tickets in dashboard' do
    wf_params = Wf_Param.new
    wf_params.push_param('due_by', 'due_by_op', '2')
    wf_params.push_param('status', 'is_in', '2,3,6,7')
    actual = es_query(wf_params)

    outer_must = []
    outer_must.push(:bool => { :should => [{ :range => { 'due_by' => { :gte => Time.zone.now.beginning_of_day.utc.iso8601,
                                                                       :lte => Time.zone.now.end_of_day.utc.iso8601 },
                                                         :_cache => false }}], 
                                              :must => [{ :term => { 'status_stop_sla_timer' => false, 
                                                                     :_cache => false }},
                                                        { :term => { 'status_deleted' => false, 
                                                                     :_cache => false }}] })
    outer_must.push(:terms => { 'status' => ['2', '3', '6', '7'], :_cache => false })

    expected = expected_query(outer_must)
    actual.should eql(expected)
  end

  it 'should handle new tickets in dashboard' do
    wf_params = Wf_Param.new
    wf_params.push_param('status', 'is_in', '2')
    wf_params.push_param('responder_id', 'is_in', '-1')
    wf_params.push_param('status', 'is_in', '2,3,6,7')

    actual = es_query(wf_params)

    outer_must = []
    outer_must.push(:terms => { 'status' => ['2'], :_cache => false })
    outer_must.push(:bool => { :should => [{ :missing => { :field => 'responder_id' }},
                                           { :terms => {'responder_id' => [], :_cache => false }}] })
    outer_must.push(:terms => { 'status' => ['2', '3', '6', '7'], :_cache => false })

    expected = expected_query(outer_must)
    actual.should eql(expected)
  end
end
