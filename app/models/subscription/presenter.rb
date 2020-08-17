class Subscription < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at, :next_renewal_at, :discount_expires_at]
  SUBSCRIPTION_UPDATE = 'subscription_update'.freeze
  SUBSCRIPTION_CREATE = 'subscription_create'.freeze

  ADDITIONAL_INFO_ADDON_MAP = {
    'Freddy Self Service' => :fetch_freddy_self_service_sessions,
    'Freddy Ultimate' => :fetch_freddy_ultimate_sessions,
    'Freddy Session Packs Monthly' => :fetch_freddy_additional_pack_sessions,
    'Freddy Session Packs Quarterly' => :fetch_freddy_additional_pack_sessions,
    'Freddy Session Packs Half Yearly' => :fetch_freddy_additional_pack_sessions,
    'Freddy Session Packs Annual' => :fetch_freddy_additional_pack_sessions
  }.freeze

  acts_as_api

  api_accessible :central_publish do |s|
    s.add :id
    s.add proc { |s| s.amount.to_i }, as: :amount
    s.add :card_number
    s.add :card_expiration
    s.add :state
    s.add :subscription_plan_id
    s.add :account_id
    s.add :renewal_period
    s.add :billing_id
    s.add :subscription_discount_id
    s.add :subscription_affiliate_id
    s.add :agent_limit
    s.add :free_agents
    s.add :format_addons, as: :addons
    s.add proc { |sub| sub.freddy_sessions.to_i }, as: :freddy_sessions
    s.add proc { |sub| sub.freddy_session_packs.to_i }, as: :freddy_session_packs
    s.add proc { |sub| sub.freddy_billing_model }, as: :freddy_billing_model
    s.add proc { |s| s.day_pass_amount.to_i }, as: :day_pass_amount
    s.add :subscription_currency_id
    s.add proc { |ap| ap.subscription_plan.display_name }, as: :account_plan
    s.add proc { |ap| ap.subscription_plan.name }, as: :plan_name
    DATETIME_FIELDS.each do |key|
      s.add proc { |d| d.utc_format(d.safe_send(key)) }, as: key
    end
    s.add proc { |x| x.currency.name }, as: :currency
    s.add proc { |x| x.currency.exchange_rate.to_f }, as: :exchange_rate
  end

  def event_info action
    {
      ip_address: Thread.current[:current_ip],
      pod: ChannelFrameworkConfig['pod']
    }
  end

  def model_changes_for_central
    previous_changes.merge(addon_changes_for_central)
  end

  def addon_changes_for_central
    model_changes = {}
    old_freddy_sessions = @old_subscription.freddy_sessions
    old_freddy_session_packs = @old_subscription.freddy_session_packs
    old_freddy_billing_model = @old_subscription.freddy_billing_model
    if @old_addons.present? || addons.present?
      old_addons_map = Hash[@old_addons.collect { |addon| [addon.name, addon] }]
      new_addons_map = Hash[addons.collect { |addon| [addon.name, addon] }]
      addon_changes = {
        added: get_added_or_removed_addons(addons, old_addons_map),
        removed: get_added_or_removed_addons(@old_addons, new_addons_map, @old_subscription),
        updated: get_updated_addons(new_addons_map)
      }
      model_changes[:addons] = addon_changes
    end
    model_changes[:freddy_sessions] = [old_freddy_sessions, freddy_sessions] if old_freddy_sessions != freddy_sessions
    model_changes[:freddy_session_packs] = [old_freddy_session_packs, freddy_session_packs] if old_freddy_session_packs != freddy_session_packs
    model_changes[:freddy_billing_model] = [old_freddy_billing_model, freddy_billing_model] if old_freddy_billing_model != freddy_billing_model
    model_changes
  end

  def get_added_or_removed_addons(add_ons, addons_map, sub = self)
    add_ons.each_with_object([]) do |addon, addons_list|
      addons_list << format_addon(addon, sub) if addons_map[addon.name].blank?
    end
  end

  def get_updated_addons(addon_map)
    @old_addons.each_with_object([]) do |addon, addons_list|
      new_addon = addon_map[addon.name]
      addons_list << [format_addon(addon, @old_subscription), format_addon(new_addon)] if new_addon.present? && addon.billing_quantity(@old_subscription) != new_addon.billing_quantity(self)
    end
  end

  def self.disallow_payload?(payload_type)
    return false if payload_type == SUBSCRIPTION_UPDATE

    super
  end

  def relationship_with_account
    "subscription"
  end

  def bundle_info(payload_type)
    return {} unless [SUBSCRIPTION_CREATE, SUBSCRIPTION_UPDATE].include?(payload_type)

    {
      bundle: {
        type: Account.current.omni_bundle_name
      }
    }
  end

  private

    def format_addons(add_ons = addons, sub = self)
      addon_list = []
      add_ons.each do |addon|
        addon_list.push(format_addon(addon, sub))
      end
      addon_list
    end

    def format_addon(addon, sub = self)
      quantity = addon.billing_quantity(sub)
      addon_name = addon.name
      addon_additional_info = ADDITIONAL_INFO_ADDON_MAP[addon_name]
      result = { name: addon_name }
      result[:quantity] = quantity if quantity.present?
      result[:additional_info] = safe_send(addon_additional_info, sub) if addon_additional_info
      result
    end

    def fetch_freddy_self_service_sessions(sub)
      { included_sessions: sub.freddy_self_service_sessions }
    end

    def fetch_freddy_ultimate_sessions(sub)
      { included_sessions: sub.freddy_ultimate_sessions }
    end

    def fetch_freddy_additional_pack_sessions(sub)
      { included_sessions: sub.freddy_additional_pack_sessions }
    end
end
