require Rails.root.join('test', 'api', 'helpers', 'canned_response_folders_test_helper.rb')
# require_relative '../../test_helper'
['canned_response_folders_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
load 'spec/support/canned_responses_helper.rb'
module CannedResponsesSandboxHelper
  include CannedResponseFoldersTestHelper
  include CannedResponsesHelper

  ACTIONS = ['delete', 'update', 'create']
  def canned_responses_data(account)
    all_canned_responses_data = []
    ACTIONS.each do |action|
      all_canned_responses_data << send("#{action}_canned_responses_data", account)
    end
    all_canned_responses_data.flatten
  end

  def create_canned_responses_data(account)
    canned_responses_data = []
    file = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    3.times do
      @account = account
      canned_response = create_response(
          title: Faker::Lorem.sentence,
          content_html: "Hi, #{Faker::Lorem.paragraph} Regards, #{Faker::Name.name}",
          visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          user_id: account.users.first.id,
      )
      canned_responses_data << [canned_response.attributes.merge({"action" => 'added', "model"=> canned_response.class.name})]
    end
    canned_responses_data.flatten
  end

  def delete_canned_responses_data(account)
    canned_response = account.canned_responses.last
    return [] unless canned_response
    data = canned_response.attributes.clone
    canned_response.soft_delete!
    [data.merge({"action" => 'deleted', "model" => canned_response.class.name})]
  end

  def update_canned_responses_data(account)
    canned_response = account.canned_responses.last
    return [] unless canned_response
    canned_response.title = Faker::Lorem.sentence
    data = canned_response.changes.clone
    canned_response.save
    [Hash[data.map { |k, v| [k, v[1]] }].merge({"id" =>canned_response.id, "action" => 'modified', "model" => canned_response.class.name })]
  end
end
