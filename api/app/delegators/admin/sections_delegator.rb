module Admin
  class SectionsDelegator < BaseDelegator
    attr_accessor :record
    validate :empty_section_fields?, if: -> { record.present? }, on: :destroy

    def initialize(record, options)
      self.record = record
      super(record, options)
    end

    private

      def empty_section_fields?
        errors[:existing_section_fields] << :non_empty_section_fields if record.section_fields.exists?
      end
  end
end
