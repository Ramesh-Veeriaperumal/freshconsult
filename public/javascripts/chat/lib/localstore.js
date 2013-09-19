(function($){
    localStore = {
        islocalStore : function(){
            try{
                return 'localStorage' in window && window['localStorage'] !== null;
            }catch(e){
                return false;
            }
        },
        IsJson : function(str){
            try {
                JSON.parse(str);
            } catch (e) {
                return false;
            }
            return true;
        },
        isPresent : function(data, value){
            if(data != null){
                var cont = data.split('#');
                var len = cont.length;
                for(var i=0; i< len; i++){
                    var id = this.IsJson(cont[i]) ? JSON.parse(cont[i]).id : cont[i];
                    if(id == value){
                        return true;
                    }
                }
            }
            return false;
        },
        store : function(name, value, type){
            var expires = "",
                expdate = new Date(),
                id;
            expdate.setDate(expdate.getDate() + 10000);
            expires = "; expires="+expdate.toGMTString();
            id = value;
            if(typeof value == 'object'){
                id = value.id;
                var value = JSON.stringify(value);
            }
            if(type != "remove"){
                var data = this.get(name);
                if(this.isPresent(data,id)){
                    return;
                }
                if(data != null && data != ""){
                    value = data +"#"+ value;
                }
            }
            var encoded_key = name+this.encode(CURRENT_USER.id);
            var encoded_value = this.encode(value);
            if(this.islocalStore()){
                localStorage.setItem(encoded_key, encoded_value);
            }else{
                if(!encoded_value || type=="remove"){
                     document.cookie = name + CURRENT_USER.id+'=; expires=Sat, 01 Jan 2000 00:00:01 GMT;';
                }
                else{
                    document.cookie = name+CURRENT_USER.id+"="+encoded_value+expires+"; path=/";
                }
            }
        },
        get : function(name){
            var encoded_key = name+this.encode(CURRENT_USER.id);
            if(this.islocalStore()){
                return this.decode(localStorage.getItem(encoded_key));
            }else{
                var data = name+CURRENT_USER.id + "=";
                var cont = document.cookie.split(';');
                var len = cont.length;
                for(var i=0; i< len; i++){
                    var c = cont[i];
                    while(c.charAt(0)==' '){
                        c = c.substring(1, c.length);
                    }
                    if(c.indexOf(data) == 0){
                        return this.decode(c.substring(data.length, c.length));
                    }
                }
                return null;
            }
        },
        remove : function(name, value){
            var newValue = "";
            var data = this.get(name);
            if(data != null){
                var cont = data.split('#');
                var len = cont.length;
                for(var i=0; i< len; i++){
                    var id = this.IsJson(cont[i]) ? JSON.parse(cont[i]).id : cont[i];
                    if(id != value){
                        if(newValue.length>0){
                            newValue += "#";
                        }
                        newValue += cont[i];
                    }
                }
            }
            var encoded_key = name + this.encode(CURRENT_USER.id);
            if(this.islocalStore()){
                if(newValue == "" || value == "all"){
                    localStorage.removeItem(encoded_key);
                }else{
                    localStorage.setItem(encoded_key, this.encode(newValue));
                }
            }else{
                this.store(name, newValue, "remove");
            }
        },

        encode : function(input){
            return Base64.encode(input);
        },

        decode : function(output){
            return output ? Base64.decode(output) : output;
        }
    }
})(jQuery);