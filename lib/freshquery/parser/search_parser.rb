module Freshquery
  module Parser
#
# DO NOT MODIFY!!!!
# This file is automatically generated by Racc 1.4.14
# from Racc grammer file "".
#

require 'racc/parser.rb'
class SearchParser < Racc::Parser

module_eval(<<'...end search.y/module_eval...', 'search.y', 20)
  require 'strscan'
  require 'json'

  def parse(str)
    scanner = StringScanner.new str
    @tokens = []
    @record = {}
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
    relational_x = "(>|<)"
    date_x = "[\s]*'\\d{4}-\\d{2}-\\d{2}'"
    value_x = "[\s]*([a-zA-Z0-9_\@]+|'[^']+'|[-]?[0-9]+)"
    term_x = "(#{value_x}|#{relational_x}#{date_x})"
    regex_string = /(#{keyword_x}#{seperator_x}#{term_x})/
    until scanner.empty?
      case
        when match = scanner.scan(/\([\s]*/)
          @tokens.push [:LPAREN, match.strip]    
        when match = scanner.scan(/[\s]*\)/)
          @tokens.push [:RPAREN, match.strip]
        when match = scanner.scan(/[\s]+(AND|OR)[\s]+/i)
          @tokens.push [match.strip.upcase.to_sym, match.strip.upcase]
        when match = scanner.scan(regex_string) # match any keyword:value
          @tokens.push [:PAIR, match]
        else
          current_pos = scanner.pos
          rest = scanner.rest
          error_scanner = StringScanner.new rest
          [/#{keyword_x}/,/#{seperator_x}/,/#{term_x}/].each { |x|
            unless error_scanner.scan(x)
              current_pos += error_scanner.pos
              raise ParseError, "Unable to parse the query, << #{error_scanner.rest[0,8]} >> at #{current_pos}, Allowed format is keyword:value or keyword:'value'"
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
      elsif (stack.length == 0 or stack.last == '(') and (is_logical_operator?(element))
        stack << element
      elsif element == '('
        stack << element
      elsif element == ')'
        until stack.last == '(' do
          top = stack.pop
          postfix << top
        end
        stack.pop
      elsif is_logical_operator?(element) and is_logical_operator?(stack.last) and precedence(element) > precedence(stack.last)
        stack << element
      elsif element == stack.last
        postfix << element
      elsif is_logical_operator?(element) and is_logical_operator?(stack.last) and precedence(element) < precedence(stack.last)
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

  def record
    @record
  end

  def expression_tree(input_array = tokens)
    postfix = infix_to_postfix(input_array)
    stack = []
    postfix.each do |element|
      if is_operand?(element)
        condition = element.split(":")
        keyword = condition[0].strip.downcase
        ope, condition[1] = get_operator(condition[1])
        value = (condition[1, condition.length].join(":")).strip
        if value == "null"
          value = nil
        else
          value = is_integer?(value) ? value.to_i : value
          value = value =~ /\'(.*)\'/ ? value[1,value.length-2] : value
        end
        data = { keyword => value }
        if @record.key?(keyword)
          @record[keyword] << value
        else
          @record[keyword] = [value]
        end
        node = OperandNode.new(data, ope)
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

  def get_operator(value)
    ope = value[0]
    case
      when [">","<"].include?(ope)
        value[0] = ''
        return [ope, value]
      else
        return [":", value]
    end
  end

  def is_logical_operator?(element)
    ['AND','OR'].include?(element)
  end

  def is_operator?(element)
    is_logical_operator?(element) || ['(',')'].include?(element)
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


...end search.y/module_eval...
##### State transition tables begin ###

racc_action_table = [
   4,     3,     3,     3,     2,     2,     2,     8,     5,     6,
   5,     6,     3,    11,   nil,     2,     5,     6,     5,     6 ]

racc_action_check = [
   1,     2,     0,     6,     2,     0,     6,     4,     1,     1,
   7,     7,     5,     7,   nil,     5,    10,    10,     9,     9 ]

racc_action_pointer = [
  -5,     0,    -6,   nil,     7,     5,    -4,     2,   nil,    10,
   8,   nil ]

racc_action_default = [
  -5,    -5,    -5,    -4,    -5,    -5,    -5,    -5,    12,    -2,
  -3,    -1 ]

racc_goto_table = [
   1,   nil,     7,   nil,   nil,     9,    10 ]

racc_goto_check = [
   1,   nil,     1,   nil,   nil,     1,     1 ]

racc_goto_pointer = [
 nil,     0 ]

racc_goto_default = [
 nil,   nil ]

racc_reduce_table = [
0, 0, :racc_error,
3, 13, :_reduce_1,
3, 13, :_reduce_2,
3, 13, :_reduce_3,
1, 13, :_reduce_4 ]

racc_reduce_n = 5

racc_shift_n = 12

racc_token_table = {
false => 0,
:error => 1,
":" => 2,
">" => 3,
"<" => 4,
"AND" => 5,
"OR" => 6,
:PAIR => 7,
:OR => 8,
:AND => 9,
:LPAREN => 10,
:RPAREN => 11 }

racc_nt_base = 12

racc_use_result_var = true

Racc_arg = [
racc_action_table,
racc_action_check,
racc_action_default,
racc_action_pointer,
racc_goto_table,
racc_goto_check,
racc_goto_default,
racc_goto_pointer,
racc_nt_base,
racc_reduce_table,
racc_token_table,
racc_shift_n,
racc_reduce_n,
racc_use_result_var ]

Racc_token_to_s_table = [
"$end",
"error",
"\":\"",
"\">\"",
"\"<\"",
"\"AND\"",
"\"OR\"",
"PAIR",
"OR",
"AND",
"LPAREN",
"RPAREN",
"$start",
"expr" ]

Racc_debug_parser = false

##### State transition tables end #####

# reduce 0 omitted

module_eval(<<'.,.,', 'search.y', 12)
def _reduce_1(val, _values, result)
   result = val.join(' ') 
  result
end
.,.,

module_eval(<<'.,.,', 'search.y', 13)
def _reduce_2(val, _values, result)
   result = val.join(' ') 
  result
end
.,.,

module_eval(<<'.,.,', 'search.y', 14)
def _reduce_3(val, _values, result)
   result = val.join(' ') 
  result
end
.,.,

module_eval(<<'.,.,', 'search.y', 15)
def _reduce_4(val, _values, result)
   
  result
end
.,.,

def _reduce_none(val, _values, result)
val[0]
end

end   # class SearchParser


  end
end