module Paperclip
  class Attachment
    # Change the default options to use :filename
    def self.default_options
      @default_options ||= {
        :url           => "/system/:attachment/:id/:style/:filename",
        :path          => ":rails_root/public/system/:attachment/:id/:style/:filename",
        :styles        => {},
        :default_url   => "/:attachment/:style/missing.png",
        :default_style => :original,
        :validations   => {},
        :storage       => :filesystem
      }
    end

    # Added :filename, which solves problems for files with
    # no extension
    def self.interpolations
      @interpolations ||= {
        :rails_root   => lambda{|attachment,style| RAILS_ROOT },
        :rails_env    => lambda{|attachment,style| RAILS_ENV },
        :class        => lambda do |attachment,style|
                           attachment.instance.class.name.underscore.pluralize
                         end,
        :filename     => lambda do |attachment,style|
                           attachment.original_filename
                         end,
        :basename     => lambda do |attachment,style|
                           attachment.original_filename.gsub(/#{File.extname(attachment.original_filename)}$/, "")
                         end,
        :extension    => lambda do |attachment,style| 
                           ((style = attachment.styles[style]) && style[:format]) ||
                           File.extname(attachment.original_filename).gsub(/^\.+/, "")
                         end,
        :id           => lambda{|attachment,style| attachment.instance.id },
        :id_partition => lambda do |attachment, style|
                           ("%09d" % attachment.instance.id).scan(/\d{3}/).join("/")
                         end,
        :attachment   => lambda{|attachment,style| attachment.name.to_s.downcase.pluralize },
        :style        => lambda{|attachment,style| style || attachment.default_style },
      }
    end
  end
end