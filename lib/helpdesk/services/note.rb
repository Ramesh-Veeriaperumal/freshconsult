module Helpdesk
  module Services
    module Note
      include ::Utils::Sanitizer

      def save_note
        build_note_and_sanitize
        self.save
      end

      def save_note!
        build_note_and_sanitize
        self.save!
      end

      def update_note_attributes(attributes)
        attributes = sanitize_body_hash(attributes,:note_body_attributes,"body","full_text") if(attributes)
        self.update_attributes(attributes)
      end

      def build_note_and_sanitize
        build_note_body unless note_body
        if note_body
          self.load_full_text
          sanitize_body_and_unhtml_it(note_body,"body","full_text")
        end
      end
    end
  end
end
