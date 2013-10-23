module Helpdesk
  module Services
    module Note
      include Utils::Sanitizer

      def save_note
        build_note_body unless note_body
        if note_body
          note_body.load_full_text
          sanitize_body_and_unhtml_it(note_body,"body","full_text")
        end
        self.save
      end

      def save_note!
        build_note_body unless note_body
        if note_body
          note_body.load_full_text
          sanitize_body_and_unhtml_it(note_body,"body","full_text")
        end
        self.save!
      end

      def update_note_attributes(attributes)
        attributes = sanitize_body_hash(attributes,:note_body_attributes,"body","full_text") if(attributes)
        self.update_attributes(attributes)
      end
    end
  end
end
