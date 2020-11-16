# frozen_string_literal: true

require_relative '../../../../../../test/api/api_test_helper'
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class Reports::Freshchat::SummaryReportsControllerFlowNewTest < ActionDispatch::IntegrationTest
  include UsersHelper

  def test_index_summary_reports
    agent = add_test_agent(@account)
    url = 'http://' + ChatConfig['communication_url']
    req_stub = stub_request(:post, url + '/sites').to_return(status: 200, body: site_params.to_json, headers: {})
    set_request_auth_headers(agent)
    post '/livechat/enable'
    get '/reports/freshchat/summary_reports'
    assert_template('chat')
    assert_response 200
  ensure
    remove_request_stub(req_stub)
  end

  def test_export_pdf
    agent = add_test_agent(@account)
    set_request_auth_headers(agent)
    params = { data_hash: { date: { date_range: '30 Oct 2020 - 06 Nov 2020', presetRange: false }, report_filters: [{ name: 'widget_id', value: 'all' }, { name: 'chat_type', value: '1' }], select_hash: [{ name: 'Widget', value: 'All' }, { name: 'Chat Type', value: 'Visitor Initiated' }] } }
    post '/reports/freshchat/summary_reports/export_pdf', params
    assert_response 200
  end

  def test_save_update_delete_reports_filter
    agent = add_test_agent(@account)
    agent_report_filters_before_create = agent.report_filters.count
    set_request_auth_headers(agent)
    post '/reports/freshchat/summary_reports/save_reports_filter', params_hash(agent)
    assert_response 200
    assert_equal agent_report_filters_before_create + 1, agent.report_filters.count
    params = { filter_name: 'New filter 1', id: agent.report_filters.last.id }
    post '/reports/freshchat/summary_reports/update_reports_filter', params.merge!(params_hash(agent).except(:filter_name))
    assert_response 200
    post '/reports/freshchat/summary_reports/delete_reports_filter', id: agent.report_filters.last.id
    assert_response 200
    assert_equal agent_report_filters_before_create, agent.report_filters.count
  end

  private

    def site_params
      {
        data: {
          site: {
            site_id: '1234567890'

          },
          widget: {
            widget_id: '234565434fgyt5678'
          }
        }
      }
    end

    def params_hash(agent)
      {
        filter_name: 'New filter',
        data_hash: {
          date: {
            date_range: '30 Oct 2020 - 06 Nov 2020',
            presetRange: false
          },
          schedule_config: {
            scheduled_task: {
              frequency: '3',
              day_of_frequency: '4',
              minute_of_day: 240
            },
            schedule_configuration: {
              config: {
                subject: 'subject',
                description: 'desc',
                emails: email_params(agent)
              }
            },
            enabled: true
          },
          report_filters: [
            {
              name: 'widget_id',
              value: 'all'
            },
            {
              name: 'chat_type',
              value: '1'
            }
          ],
          select_hash: [
            {
              name: 'Widget',
              value: 'All'
            },
            {
              name: 'Chat Type',
              value: 'Visitor Initiated'
            }
          ]
        }
      }
    end

    def email_params(agent)
      email_param = {}
      email_param[agent.email.to_sym] = agent.id.to_s
      email_param
    end

    def old_ui?
      true
    end
end
