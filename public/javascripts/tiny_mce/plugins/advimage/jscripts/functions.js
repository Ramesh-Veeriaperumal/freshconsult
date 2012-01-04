function ts_insert_image(url, alt_text){
 var formObj = document.forms[0]; formObj.src.value = url;
 formObj.alt.value = alt_text;
 insertAction();
}