class PopulateIndexNamesInElasticsearchIndices < ActiveRecord::Migration
  def self.up
    range = Rails.env.development? ? (2..2) : (1..50)
    range.each do |i|
      record = ElasticsearchIndex.new(:name => "fd_index-#{i}")
      record.id = i
      record.save
    end
  end

  def self.down
    ElasticsearchIndex.delete_all
  end
end
