// JS FUNCTIONS

// Put new message at end of messages div.
function appendMessage(msg){
	console.log("Receiving message: " + msg);
	//document.getElementById('messages').appendChild(document.createTextNode(msg));
	//document.getElementById('messages').innerHTML += '<br>'
	var div = document.getElementById('messages');
	div.insertAdjacentHTML('afterbegin', "<br>");
	div.insertAdjacentText('afterbegin', msg);
}

function appendMessagesToTable(message_array){
	if(message_array['action'] === 'add'){
		model.messages.push.apply(model.messages, message_array['data'].reverse());
		// model.messages(message['data']);
		// message['data'].map(function(item){
		// 	model.addMessage(item);
		// });
	} else {
		model.addMessage(message_array);
	}
}

// Do something with received published message.
function handlePublishedMessage(message){
	//appendMessage(message.action + ":  " + message.text);
	console.log('HANDLING PUBLISHED MESSAGE: ' + JSON.stringify(message));
	// if(message['action'] === 'add'){
	// 	model.messages(message['data']);
	// 	// message['data'].map(function(item){
	// 	// 	model.addMessage(item);
	// 	// });
	// } else {
	// 	model.addMessage(message);
	// }
	appendMessagesToTable(message);
}

// Generate random UUID
function guid(){return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c)
{var r = Math.random()*16|0,v=c=='x'?r:r&0x3|0x8;return v.toString(16);});}


// Super basic ajax call.
function ajax(method, path, callback) {
  var xhttp = new XMLHttpRequest();
  xhttp.open("GET", path, true);
  xhttp.setRequestHeader('X-Requested-With','XMLHttpRequest');
  xhttp.onreadystatechange = function() {
    if (xhttp.readyState == 4 && xhttp.status == 200) {
      //document.getElementById("demo").innerHTML = xhttp.responseText;
			//console.log("Connected to private faye channel.");
			callback(xhttp);
    }
  }
  xhttp.send();
}

function fayeSubscribe(ch, fn) {
	faye.unsubscribe(ch);
	var subscription = faye.subscribe(ch, fn);
	subscription.then(function(){console.log('Subscribed to ' + ch)});
	return subscription
}

// Subscribe to private channel (to/from server)
function subscribePrivate(uuid) {
	faye_client_uuid = (typeof(uuid) === "undefined" ? faye._dispatcher.clientId : uuid);
  private_channel_subscription = fayeSubscribe('/' + faye_client_uuid, handlePublishedMessage);
  return faye_client_uuid;
}
// This is attempt to subscript to private server channel without knowing clientId,
// but it appears too difficult to change a subscription once it is successful.
// function subscribePrivate() {
//   private_channel_subscription = fayeSubscribe('/private/server', handlePublishedMessage);
//   private_channel_subscription.then(function(){
// 	  private_channel_subscription._channels = ("/" + private_channel_subscription._client._dispatcher.clientId);
// 	  console.log("Private channels: " + private_channel_subscription._channels);
// 	});
// 	faye_client_uuid = null;
// }

// DOM LOADED
document.addEventListener("DOMContentLoaded", function() {
	// Connect to fay server
	faye = new Faye.Client('http://' + hostname + ':' + portnum + '/fayeserver');

	// Create a private channel with the server.
	//ajax('GET', '/ws/subscribe', function(xhttp){subscribePrivate(xhttp.responseText)});
	
	// Only subscribePrivate once faye makes connection - and gets clientId.
	// I moved this to bottom of <body> on layout, but it doesn't seem to force
	// recent messages to load last all-at-once with private subscription.
	faye.connect(subscribePrivate); //(guid());
	
	
	
	// Open a standard websocket.
	// ws = new WebSocket("ws://" + hostname + ":" + portnum + "/");
	// ws.onmessage = function(evnt){
	// 	appendMessage(evnt.data);
	// }
});

