# encoding: utf-8
require 'open-uri'
require 'digest/sha1'
 
class RemoteFile < ::Tempfile
 
   attr_accessor :open_uri_path

  def initialize(path, tmpdir = Dir::tmpdir)
    @original_filename  = File.basename(path).split('=')[1] || File.basename(path)
    @remote_path        = path
 
    super Digest::SHA1.hexdigest(path), tmpdir
    fetch
  end
 
  def fetch
    string_io = OpenURI.send(:open, @remote_path)
    self.open_uri_path = string_io.path 
    self.write string_io.read
    self.rewind
    self
  end
 
  def unlink_open_uri
    FileUtils.rm_rf open_uri_path
  end

  def original_filename
    @original_filename
  end
 
  def content_type
    mime = `file --mime -br #{self.path}`.strip
    mime = mime.gsub(/^.*: */,"")
    mime = mime.gsub(/;.*$/,"")
    mime = mime.gsub(/,.*$/,"")
    mime
  end
end