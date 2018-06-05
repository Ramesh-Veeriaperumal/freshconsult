['test_case_methods.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
module CustomDashboardTestHelper
  include TestCaseMethods
  include ::Dashboard::Custom::CustomDashboardConstants

  def wrap_cname(parameters)
    { custom_dashboard: parameters }
  end

  def match_dashboard_response(response_hash, dashboard_hash)
    match_custom_json(sanitize_response(response_hash), dashboard_hash)
  end

  def match_dashboard_index_payload(response_hash, dashboard_list)
    match_custom_json(sanitize_dashboard_index_response(response_hash), format_dashboard_list(dashboard_list))
  end

  def sanitize_dashboard_index_response(response_hash)
    formatted_dashboard_response = []
    response_hash.each { |dashboard_item| formatted_dashboard_response << dashboard_item.slice(:name, :type, :group_ids) }
    formatted_dashboard_response
  end

  def format_dashboard_list(dashboard_list)
    formatted_dashboard_list = []
    dashboard_list.each do |dashboard|
      formatted_dashboard_list << dashboard.get_dashboard_index_payload
    end
    formatted_dashboard_list
  end


  def sanitize_response(response_hash)
    assert_not_nil_and_delete(response_hash, [:id, :last_modified_since])
    response_hash[:widgets].map { |widget| assert_not_nil_and_delete(widget, [:id, :active]) }
    response_hash
  end

  def assert_not_nil_and_delete(response_hash, keys)
    keys.each do |key|
      assert_not_nil response_hash[key]
      response_hash.delete(key)
    end
  end

  def bar_chart_preview_es_response_stub(field_id, choices = [2, 8, 4])
    [{
      :total => 14,
      :doc_counts => {
        'name' =>  {
          'doc_count_error_upper_bound' => 0,
          'sum_other_doc_count' => 0,
          'buckets' => [
            { 'key' => choices[0], 'doc_count' => 11 },
            { 'key' => choices[1], 'doc_count' => 2 },
            { 'key' => choices[2], 'doc_count' => 1 }
          ]
        }
      },
      'group_by' => field_id
    }]
  end

  def bar_chart_preview_response_pattern(field_id, choices = [2, 8, 4])
    {
      'data' => [
        { 'data' => [11], 'name' => choices[0] },
        { 'data' => [2], 'name' => choices[1] },
        { 'data' => [1], 'name' => choices[2] }
      ],
      'group_by' => field_id
    }
  end

  def bar_chart_preview_response_percentage_pattern(field_id, choices = [2, 8, 4])
    {
      'data' => [
        { 'data' => [78.6], 'name' => choices[0] },
        { 'data' => [14.3], 'name' => choices[1] },
        { 'data' => [7.1], 'name' => choices[2] }
      ],
      'group_by' => field_id
    }
  end

  def create_dashboard_with_widgets(options, widgets_count, widget_type, widget_options = [])
    dashboard_object = options.present? ? DashboardObject.new(options[:access_type], options[:group_ids]) : DashboardObject.new
    update_dashboard_list(dashboard_object)
    widgets_count.times { |n| dashboard_object.add_widget(widget_type, widget_options[n]) }
    db_record = @account.dashboards.create(dashboard_object.get_dashboard_payload(:db))
    dashboard_object.set_db_record(db_record)
    db_record
  end

  def fetch_scorecard_stub(widgets)
    stub_data = {}
    widgets.map(&:ticket_filter_id).uniq.each do |filter|
      stub_data[filter.to_s.to_sym] = rand(1000)
    end
    stub_data
  end

  def scorecard_response_pattern(widgets, stub_data)
    widgets.map { |widget| { id: widget.id, widget_data: { count: stub_data[widget.ticket_filter_id.to_s.to_sym] } } }
  end

  def fetch_bar_chart_stub(widgets)
    stub_data = []
    widgets.map(&:config_data).each do |config|
      stub_data << {
        total: 125,
        doc_counts: {
          'name' => {
            'buckets' => [{ 'key' => 3, 'doc_count' => 45 }, { 'key' => 2, 'doc_count' => 29 }, { 'key' => 11, 'doc_count' => 25 }, { 'key' => 8, 'doc_count' => 18 }, { 'key' => 12, 'doc_count' => 8 }]
          }
        },
        'group_by' => config[:categorised_by]
      }
    end
    stub_data
  end

  def bar_chart_response_pattern(widgets, stub_data)
    widgets.each_with_index.map do |widget, i|
      {
        id: widget.id,
        widget_data: {
          group_by: widget.config_data[:categorised_by],
          data: stub_data[i][:doc_counts]['name']['buckets'].map { |stub| { name: stub['key'], data: [stub['doc_count']] } }
        }
      }
    end
  end

  def bar_chart_data_es_response_stub(widget, choices = [2, 8, 4, 14, 5, 9, 12, 22, 11])
    [{
      :total => 143,
      :doc_counts => {
        'name' =>  {
          'doc_count_error_upper_bound' => 0,
          'sum_other_doc_count' => 0,
          'buckets' => [
            { 'key' => choices[0], 'doc_count' => 40 },
            { 'key' => choices[1], 'doc_count' => 21 },
            { 'key' => choices[2], 'doc_count' => 11 },
            { 'key' => choices[3], 'doc_count' => 10 },
            { 'key' => choices[4], 'doc_count' => 8 },
            { 'key' => choices[5], 'doc_count' => 6 },
            { 'key' => choices[6], 'doc_count' => 4 },
            { 'key' => choices[7], 'doc_count' => 2 },
            { 'key' => choices[8], 'doc_count' => 1 }
          ]
        }
      },
      'group_by' => widget.config_data['categorised_by']
    }]
  end

  def bar_chart_data_response_pattern(widget, choices = [2, 8, 4, 14, 5, 9, 12, 22, 11])
    {
      'data' => [
        { 'data' => [40], 'name' => choices[0] },
        { 'data' => [21], 'name' => choices[1] },
        { 'data' => [11], 'name' => choices[2] },
        { 'data' => [10], 'name' => choices[3] },
        { 'data' => [8], 'name' => choices[4] },
        { 'data' => [6], 'name' => choices[5] },
        { 'data' => [4], 'name' => choices[6] },
        { 'data' => [2], 'name' => choices[7] },
        { 'data' => [1], 'name' => choices[8] }
      ],
      'group_by' => widget.config_data['categorised_by']
    }
  end

  def trend_card_reports_response_stub(t = '50', f = '40')
    result = [{
      'result' => [
        { range_benchmark: 'f', count: f },
        { range_benchmark: 't', count: t }
      ]
    }]
    [result, nil, nil]
  end

  def trend_card_preview_response_pattern(stub)
    {
      data: [
        { range_benchmark: 'f', count: stub[0][0]['result'][0][:count] },
        { range_benchmark: 't', count: stub[0][0]['result'][1][:count] }
      ]
    }
  end

  def fetch_trend_card_stub(widgets)
    stub_data = []
    widgets.each do |widget|
      stub_data << {
        'result' => [
          { range_benchmark: 'f', count: rand(100) },
          { range_benchmark: 't', count: rand(100) }
        ],
        'index' => nil
      }
    end
    [stub_data, nil, nil]
  end

  def trend_card_response_pattern(widgets, stub_data)
    widgets.each_with_index.map do |widget, i|
      {
        id: widget.id,
        widget_data: stub_data[0][i]['result']
      }
    end
  end
end
