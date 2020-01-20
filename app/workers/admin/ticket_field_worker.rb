class Admin::TicketFieldWorker < BaseWorker
  include TicketFieldBuilder

  sidekiq_options queue: :ticket_field_job, retry: 0, failures: :exhausted

  attr_accessor :validation_context, :action, :requester_params, :item, :tf

  def perform(args)
    args.symbolize_keys!
    account_id = args[:account_id]
    Account.find(account_id).make_current
    @item = @tf = Account.current.ticket_fields_with_nested_fields.find(args[:ticket_field_id])
    self.validation_context = self.action = args[:action]
    self.requester_params = deep_symbolize_keys(args[:requester_params] || {})
    begin
      build_custom_choices(tf, cname_params[:choices])
      if create?
        tf.save!
      else
        ActiveRecord::Base.transaction do
          tf.field_options[:update_in_progress] = false
          save_picklist_choices
          tf.save!
        end
      end
    rescue StandardError => e
      # save it in case of failure.
      tf.reload
      tf.field_options[:update_in_progress] = false
      tf.save!
      Rails.logger.info "Choices update FAILED => #{e.inspect}"
      NewRelic::Agent.notice_error(e, args: { account_id: account_id, ticket_field_id: args[:ticket_field_id] })
    end
  end

  def create?
    action.to_s.to_sym == :create
  end

  def update?
    action.to_s.to_sym == 'update'
  end

  def cname_params
    requester_params
  end
end
