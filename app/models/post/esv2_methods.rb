class Post < ActiveRecord::Base

  def to_esv2_json
    as_json({
        root: false,
        tailored_json: true,
        only: [ :body ]
      }).merge(attachments: es_v2_attachments).to_json
  end

  def es_v2_attachments
    attachments.pluck(:content_file_name).collect { |file_name| 
      f_name = file_name.rpartition('.')
      {
        name: f_name.first,
        type: f_name.last
      }
    }
  end

end