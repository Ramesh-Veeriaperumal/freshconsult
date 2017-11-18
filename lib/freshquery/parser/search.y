prechigh
  left ':'
  left '>'
  left '<'
  left 'AND'
  left 'OR'
preclow

token PAIR OR AND LPAREN RPAREN

rule 
  expr: LPAREN expr RPAREN { result = val.join(' ') }
  |     expr OR expr { result = val.join(' ') }
  |     expr AND expr { result = val.join(' ') }
  |     PAIR { }