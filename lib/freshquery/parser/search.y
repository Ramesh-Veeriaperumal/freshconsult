class SearchParser
	prechigh
	  left ':'
	  left '>'
	  left '<'
	  left 'AND'
	  left 'OR'
	preclow

	token PAIR OR AND LPAREN RPAREN

	rule 
	  expr:  		or_expr  { }
	  or_expr: 	or_expr OR and_expr { }
	  |       	and_expr { }
	  and_expr: and_expr AND pair { }
	  |       	pair { }
	  pair:   	PAIR { }
	  |       	LPAREN expr RPAREN { }
end