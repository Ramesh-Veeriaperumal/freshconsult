/*
The helpURLs for each of the APIs needs to be updated
in the dhValidator.helpURL once help documentation is available
*/
var appPlaceholderValidator = appPlaceholderValidator || {};

(function(appPhValidator){

  //error message to be displayed in console log
  errorMessageMap = {
    missingParams: "Missing parameters for ",
    referDoc: ". Please refer documentation."
  };

  init:(function (){
  })();

  appPhValidator.checkParams = function(apiName, markup) {
    if(markup){
      return true;
    }else{
      this.showError(apiName);
      return false;
    }
  }

  appPhValidator.showError = function(apiName){
    console.error(errorMessageMap.missingParams + apiName + errorMessageMap.referDoc);
  }

})(appPlaceholderValidator);
