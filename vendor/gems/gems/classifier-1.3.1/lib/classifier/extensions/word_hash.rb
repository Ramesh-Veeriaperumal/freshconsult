# Author::    Lucas Carlson  (mailto:lucas@rufy.com)
# Copyright:: Copyright (c) 2005 Lucas Carlson
# License::   LGPL

# These are extensions to the String class to provide convenience 
# methods for the Classifier package.
class String
  
  # Removes common punctuation symbols, returning a new string. 
  # E.g.,
  #   "Hello (greeting's), with {braces} < >...?".without_punctuation
  #   => "Hello  greetings   with  braces         "
  def without_punctuation
    tr( ',?.!;:"@#$%^&*()_=+[]{}\|<>/`~', " " ) .tr( "'\-", "")
  end
  
  # Return a Hash of strings => ints. Each word in the string is stemmed,
  # interned, and indexes to its frequency in the document.  
	def word_hash
		word_hash_for_words(gsub(/[^\w\s]/,"").split + gsub(/[\w]/," ").split)
	end

	# Return a word hash without extra punctuation or short symbols, just stemmed words
	def clean_word_hash
		word_hash_for_words gsub(/[^\w\s]/,"").split
	end
	
	private
	
	def word_hash_for_words(words)
		d = Hash.new
		words.each do |word|
			word.downcase! if word =~ /[\w]+/
			key = word.stem.intern
			if word =~ /[^\w]/ || ! CORPUS_SKIP_WORDS.include?(word) && word.length > 2
				d[key] ||= 0
				d[key] += 1
			end
		end
		return d
	end
	
	CORPUS_SKIP_WORDS = [
      "a",
      "again",
      "all",
      "along",
      "are",
      "also",
      "an",
      "and",
      "as",
      "at",
      "but",
      "by",
      "came",
      "can",
      "cant",
      "couldnt",
      "did",
      "didn",
      "didnt",
      "do",
      "doesnt",
      "dont",
      "ever",
      "first",
      "from",
      "have",
      "her",
      "here",
      "him",
      "how",
      "i",
      "if",
      "in",
      "into",
      "is",
      "isnt",
      "it",
      "itll",
      "just",
      "last",
      "least",
      "like",
      "most",
      "my",
      "new",
      "no",
      "not",
      "now",
      "of",
      "on",
      "or",
      "should",
      "sinc",
      "so",
      "some",
      "th",
      "than",
      "this",
      "that",
      "the",
      "their",
      "then",
      "those",
      "to",
      "told",
      "too",
      "true",
      "try",
      "until",
      "url",
      "us",
      "were",
      "when",
      "whether",
      "while",
      "with",
      "within",
      "yes",
      "you",
      "youll",
      ]
end