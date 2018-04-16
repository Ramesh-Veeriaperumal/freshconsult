module Concerns::CustomerNote::Callbacks
  extend ActiveSupport::Concern

  included do
    before_update :nullify_s3_key, if: :body_changed?
    after_commit :push_job_for_s3_create, on: :create
    after_commit :push_job_for_s3_update, on: :update, unless: :s3_key?
    after_commit :push_job_for_s3_delete, on: :destroy

    # note body will be pushed to s3
    # sample path "#{note_id_reversed}/#{account_id}/#{note_id}/note_body.json"

    def push_job_for_s3_create
      CustomerNotes::NoteBodyJobs.perform_async(
        create: true,
        key_id: id,
        type: klass_name
      )
    end

    def push_job_for_s3_update
      CustomerNotes::NoteBodyJobs.perform_async(
        update: true,
        key_id: id,
        type: klass_name
      )
    end

    def push_job_for_s3_delete
      CustomerNotes::NoteBodyJobs.perform_async(
        delete: true,
        key_id: id,
        type: klass_name
      )
    end

    def nullify_s3_key
      true.tap { self.s3_key = false }
    end
  end
end
