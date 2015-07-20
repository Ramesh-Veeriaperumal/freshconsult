/*
	Module to handle conflicts over the changes on JSON API.
*/
SurveyJSON={
	stringify:function(content){
	    var arrayToJson = Array.prototype.toJSON;
	    delete Array.prototype.toJSON;
	    content = JSON.stringify(content);
	    Object.defineProperty(Array.prototype, "toJSON", {
	          enumerable: false,
	          value: arrayToJson,
	          configurable:true
	        });
	    return content;
	}
}