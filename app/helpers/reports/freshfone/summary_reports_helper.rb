# Copyright © 2014 Freshdesk Inc. All Rights Reserved.
module Reports::Freshfone::SummaryReportsHelper

include Reports::GlanceReportsHelper
include Freshfone::CallHistoryHelper

  def table_headers
    { 
      :agent_name => t('reports.freshfone.agent'),
      :avg_handle_time => t('reports.freshfone.avg_handle_time'),
      :calls_count => t('reports.freshfone.agent_calls_count'),
      :answered_percentage => t('reports.freshfone.answered_percentage'),
      :call_handle_time => t('reports.freshfone.total_duration')
    }
  end

  #Used in filter_options
  def freshfone_numbers
    @freshfone_numbers ||= current_account.all_freshfone_numbers
  end

  def agent_groups_hash
    @group_hash ||= current_account.groups.reduce({ Reports::FreshfoneReport::UNASSIGNED_GROUP.to_i => t('reports.freshfone.options.unassigned')}){ |obj,c| 
      obj.merge!({c.id => c.name}) 
    }
  end

  def filter_group_options
    groups_list_options = []
    groups_list_options =  agent_groups_hash.map { |k,v| 
      { :id => k, :value => v}
    }.to_json
  end


  def filter_number_options
    number_options = [{:id => Reports::FreshfoneReport::ALL_NUMBERS, :value => t('reports.freshfone.all_numbers'), 
        :deleted => false, :name => t('reports.freshfone.all_numbers')},{:value => "", :deleted => false, :name => "" }]
    numbers_options = freshfone_numbers.reverse.reduce(number_options){|obj, c|
      obj.push({ :id => c.id, :value => c.number_name, :deleted => c.deleted, :name => c.name })
     }.to_json
  end

  def filter_default_number
    selected_number = freshfone_numbers.find(@freshfone_number)
    {:id => selected_number.id, :value => selected_number.number_name }.to_json
  end

  # Count Methods (results from query: def report_query)

  #count including tranfered calls
  def calls_count(calls)
    calls.sum(&:count)
  end

  #count without transfer calls
  def helpdesk_calls_count(calls)
    calls.sum(&:total_count)
  end

  def voicemails_count(calls)
    calls.sum(&:voicemail)
  end

  def external_transfers_count(calls)
    calls.sum(&:external_transfers) || 0
  end

  def direct_dial_count(calls)
    calls.sum(&:direct_dial_count) || 0
  end

  def unanswered_transfers(calls)
    calls.sum(&:unanswered_transfers)
  end

  def all_unanswered(calls)
    unanswered_calls_count(calls) + unanswered_transfers(calls)
  end

  #outbound_failed_call will be 0 for incoming, unanswered will be 0 for outgoing
  def unanswered_calls_count(call_list)
    call_list.inject(0) { |sum, calls|
      sum + (calls.unanswered_call + calls.outbound_failed_call)
    } || 0
  end
  # Count Methods end

  def answered_percentage(call_list)
    sum = call_list.sum(&:count)
    answered = sum - (unanswered_calls_count(call_list) + unanswered_transfers(call_list))
    percentage = ((answered/sum.to_f)*100 || 0).to_i
  end

  def avg_handle_time(call_list)
    sum = answered = 0
    call_list.each do |calls|
      next if calls.agent_name.blank?
      answered += (calls.count - (calls.unanswered_call + calls.outbound_failed_call + calls.unanswered_transfers))
      sum += calls.total_duration unless calls.total_duration.blank?
    end
    average = (answered != 0) ? sum/answered : 0
  end

  def helpdesk_handle_time(call_list)
    sum = 0
    answered =  helpdesk_calls_count(call_list) - unanswered_calls_count(call_list)
    call_list.each do |calls|
      next if calls.agent_name.blank? || calls.total_duration.blank?
      sum += calls.total_duration
    end
    average = (answered != 0) ? sum/answered : 0
  end


  def call_handle_time(call_list)
    call_list.inject(0) { |sum, calls|
      sum + calls.total_duration
    } || 0
  end

  #Used in filter_options
  def call_types
    Freshfone::Call::CALL_TYPE_HASH.map { |k,v| [t("reports.freshfone.options.#{k}"), v]}
  end

end
