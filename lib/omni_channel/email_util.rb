# frozen_string_literal: true

module OmniChannel::EmailUtil
  class Emailer < ActionMailer::Base
    def export_data(from_email, to_email, subject, message, file_list = [])
      file_list.each do |current_file|
        attachments[current_file] = {
          mime_type: 'text/csv',
          content: File.read(Rails.root.join('tmp', current_file), mode: 'rb')
        }
      end
      mail(from: from_email, to: to_email, subject: subject) do |part|
        part.html { message.to_s }
      end.deliver
    end
  end
end
