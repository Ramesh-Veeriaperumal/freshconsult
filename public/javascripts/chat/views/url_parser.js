define([], function(){
   var splitRegExp = new RegExp(
        '^' +
            '(?:' +
            '([^:/?#.]+)' +                         // scheme - ignore special characters
                                                    // used by other URL parts such as :,
                                                    // ?, /, #, and .
            ':)?' +
            '(?://' +
            '(?:([^/?#]*)@)?' +                     // userInfo
            '([\\w\\d\\-\\u0100-\\uffff.%]*)' +     // domain - restrict to letters,
                                                    // digits, dashes, dots, percent
                                                    // escapes, and unicode characters.
            '(?::([0-9]+))?' +                      // port
            ')?' +
            '(([^?#]+))?' +                           // path
            '(?:\\?([^#]*))?' +                     // query
            '(?:#(.*))?' +                          // fragment
            '$');

    return function (uri) {
        var split;
        if(!uri || uri.length==0){return {'path':""}}
        split = uri.match(splitRegExp);
        return {
            'scheme':split[1],
            'user_info':split[2],
            'domain':split[3],
            'port':split[4],
            'path':split[5],
            'query_data': split[6],
            'fragment':split[7]
        }
    };
});