class SearchParser
  prechigh
    left ':'
    left 'AND'
    left 'OR'
  preclow

  token PAIR OR AND LPAREN RPAREN

  rule 
    expr: LPAREN expr RPAREN { result = val.join(' ') }
    |     expr OR expr { result = val.join(' ') }
    |     expr AND expr { result = val.join(' ') }
    |     PAIR { }
  end

---- inner
require 'strscan'
require 'json'

def parse(str)
  scanner = StringScanner.new str
  @tokens = []
  @input = {}
  make_tokens(scanner)
  @input_array = (1..(@tokens.flatten.length)).step(2).map{|x| @tokens.flatten[x].strip }
  do_parse
end

def tokens
  @input_array
end

def make_tokens(scanner)
  keyword_x = "([a-zA-Z][a-zA-Z0-9_]*)[\s]*"
  seperator_x = ":"
  value_x = "[\s]*([a-zA-Z0-9_\@]+|'[a-zA-Z0-9_\.\@\s\:]+')"
  regex_string = /(#{keyword_x}#{seperator_x}#{value_x})+[\s]*/
  until scanner.empty?
    scanner.skip(/(\t|\r|\n|\s)+/) # Skip white spaces
    case
      when match = scanner.scan(/\(/)
        @tokens.push [:LPAREN, match]    
      when match = scanner.scan(/\)/)
        @tokens.push [:RPAREN, match]
      when match = scanner.scan(/AND|OR/i)
        @tokens.push [match.upcase.to_sym, match.upcase]
      when match = scanner.scan(regex_string) # match any keyword:value
        @tokens.push [:PAIR, match]
      else
        current_pos = scanner.pos
        rest = scanner.rest
        error_scanner = StringScanner.new rest
        error_scanner.scan(/[\t|\r|\n|\s]*/)
        [/#{keyword_x}/,/#{seperator_x}/,/#{value_x}/].each { |x|
          unless error_scanner.scan(x)
            current_pos += error_scanner.pos
            # Correct the error message
            raise ParseError, "Unable to parse the given query, << #{error_scanner.rest[0,8]} >> at #{current_pos}, Allowed format is keyword:value or keyword:'value'"
          end
        }
    end
  end
end

def next_token
  @tokens.shift
end

  def infix_to_postfix(infix)
    postfix = []
    stack = []
    current = 0
    until current == infix.length
      element = infix[current]
      if is_operand?(element)
        postfix << element
      elsif (stack.length == 0 or stack.last == '(') and (is_relational_operator?(element))
        stack << element
      elsif element == '('
        stack << element
      elsif element == ')'
        until stack.last == '(' do
          top = stack.pop
          postfix << top
        end
        stack.pop
      elsif is_relational_operator?(element) and is_relational_operator?(stack.last) and precedence(element) > precedence(stack.last)
        stack << element
      elsif element == stack.last
        postfix << element
      elsif is_relational_operator?(element) and is_relational_operator?(stack.last) and precedence(element) < precedence(stack.last)
        top = stack.pop
        postfix << top
        current -=  1
      end
      current += 1
    end
    until stack.size == 0 do
      top = stack.pop
      postfix << top    
    end
    postfix
  end

  def expression_tree(input_array = tokens)
    postfix = infix_to_postfix(input_array)
    stack = []
    postfix.each do |element|
      if is_operand?(element)
        condition = element.split(':')
        keyword = condition[0].strip.downcase
        value = (condition[1, condition.length].join(':')).strip
        value = is_integer?(value) ? value.to_i : value  #update logic and add comments
        value = value =~ /\'(.*)\'/ ? value[1,value.length-2] : value
        data = { keyword.to_sym => value }
        node = OperandNode.new(data)
        stack << node
      else
        right = stack.pop
        left = stack.pop
        data = element
        node = OperatorNode.new(data, left, right)
        stack << node
      end
    end
    root = stack.pop
  end

  def is_relational_operator?(element)
    ['AND','OR'].include?(element)
  end

  def is_operator?(element)
    is_relational_operator?(element) || ['(',')'].include?(element)
  end

  def is_operand?(element)
    !is_operator?(element)
  end

  def is_integer?(string)
    true if Integer(string) rescue false
  end

  def precedence(operator)
    precedence_hash = { OR: 10, AND: 20 }
    precedence_hash[operator.to_sym]
  end


---- footer

parser = SearchParser.new
str = ARGV.join(' ');
begin
  puts "#{parser.parse(str)}"
rescue ParseError => e
  puts e.message
end