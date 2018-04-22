module Concerns::CustomerNote::Constants
  CATEGORIES = {
    GENERAL: 1,
    TESTIMONIAL: 2
  }.freeze

  S3_BUCKET = {
    contact_note: :contact_note_body,
    company_note: :company_note_body
  }.freeze
end
