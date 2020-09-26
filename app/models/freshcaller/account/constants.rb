# frozen_string_literal: true

class Freshcaller::Account < ActiveRecord::Base
  DEFAULT_SETTINGS = {
    automatic_ticket_creation: {
      missed_calls: true,
      abandoned_calls: true,
      connected_calls: false
    }
  }.freeze
end
