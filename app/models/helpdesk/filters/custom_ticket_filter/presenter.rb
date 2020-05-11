class Helpdesk::Filters::CustomTicketFilter < Wf::Filter
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |s|
    s.add :id
    s.add :type
    s.add :name
    s.add :transform_data, as: :filter
    s.add :user_id
    s.add :model_class_name
    s.add :created_at
    s.add :updated_at
    s.add :account_id
  end

  api_accessible :central_publish_associations do |t|
    t.add :user, template: :central_publish
  end

  def central_payload_type
    action = [:create, :update, :destroy].find { |act| transaction_include_action? act }
    "ticket_filter_#{action}"
  end

  def model_changes_for_central
    model_changes = previous_changes
    if model_changes[:data].present?
      model_changes[:data].map! { |x| Helpdesk::Filters::TransformTicketFilter.new.process_args(x) }
      model_changes[:filter] = model_changes.delete(:data)
      model_changes[:updated_at] = model_changes.delete(:updated_at)
    end
    model_changes
  end

  def relationship_with_account
    :ticket_filters
  end

  def self.central_publish_enabled?
    Account.current.ticket_filters_central_publish_enabled?
  end

  private

    def transform_data
      Helpdesk::Filters::TransformTicketFilter.new.process_args(data)
    end
end
