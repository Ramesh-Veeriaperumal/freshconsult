define([ 
], function(){
	return {
		// Refer http://www.nodemailer.com for more details
  		sendMail:function(){
			var message = {
				from : '', // From Address
				to : '',  // To adress - Give comma seperated ids
				sub : '', // Subject of the mail
				content : '', // content for the mail
				attach : '' // Array of attachments
			};
			chat_socket.emit("send mail", message);
		}
  	};
});