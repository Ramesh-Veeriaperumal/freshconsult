#frozen_string_literal: true

module Redaction::Constants
  CREDIT_CARD_NUMBER_DEFAULT_OPTIONS = {
    expose_first: 0,
    expose_last: 4,
    replacement_token: 'X'
  }.freeze
end
