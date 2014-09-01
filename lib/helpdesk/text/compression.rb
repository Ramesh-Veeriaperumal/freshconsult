module Helpdesk::Text::Compression
	def self.compress(text)
		data = StringIO.new ""
		gzip_writer = Zlib::GzipWriter.new data 
		gzip_writer.write(text)
		gzip_writer.finish; 
		data.string
	end

	def self.decompress(text)
		gzip_reader =  Zlib::GzipReader.new(StringIO.new(text))
		gzip_reader.read
	end
end