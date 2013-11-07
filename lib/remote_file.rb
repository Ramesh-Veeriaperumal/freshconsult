# encoding: utf-8
require 'open-uri'
require 'digest/sha1'
 
class RemoteFile < ::Tempfile
  require 'openssl'
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
 
   attr_accessor :open_uri_path, :username, :password

  def initialize(path, username = nil, password = nil, tmpdir = Dir::tmpdir)
    @original_filename  = File.basename(path).split('=')[1] || File.basename(path)
    @remote_path        = path
    self.username = username
    self.password = password
 
    super Digest::SHA1.hexdigest(path), tmpdir
    fetch
  end
 
  def fetch
    string_io = OpenURI.send(:open, @remote_path, :http_basic_authentication => [username , password])
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