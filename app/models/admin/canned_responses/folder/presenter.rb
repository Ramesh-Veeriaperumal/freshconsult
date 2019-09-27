class Admin::CannedResponses::Folder < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at].freeze

  acts_as_api

  api_accessible :central_publish do |v|
    v.add :id
    v.add :name
    v.add :is_default
    v.add :folder_type
    v.add :deleted
    DATETIME_FIELDS.each do |key|
      v.add proc { |x| x.utc_format(x.send(key)) }, as: key
    end
  end

  def central_payload_type
    action = [:create, :update, :destroy].find { |act| transaction_include_action? act }
    return 'canned_response_folder_destroy' if @model_changes.present? && @model_changes.key?(:deleted)

    "canned_response_folder_#{action}"
  end

  def event_info(_action)
    { ip_address: Thread.current[:current_ip] }
  end

  def model_changes_for_central
    @model_changes
  end

  def relationship_with_account
    'canned_response_folders'
  end
end
