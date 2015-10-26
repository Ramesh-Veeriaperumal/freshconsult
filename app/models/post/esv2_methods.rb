class Post < ActiveRecord::Base

  def to_esv2_json
    as_json({
        root: false,
        tailored_json: true,
        only: [ :body ],
        methods: [ :attachment_names ]
      })
  end

  def attachment_names
    attachments.map(&:content_file_name)
  end

end