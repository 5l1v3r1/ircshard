require('coffee-script');
var net = require('net');
var Client = require('distobj').Client;

exports.connect = function(port, _a, _b) {
    var socket, cb = _b || _a;
    
    var errorHandler = function(e) {
        socket.removeAllListeners();
        cb(e);
    };
    var connectHandler = function() {
        var client = new Client(socket, function() {
            socket.removeListener('error', errorHandler);
            cb(null, client);
        });
    };
    
    if (_b) socket = net.connect(port, _a);
    else socket = net.connect(port);
    
    socket.once('error', errorHandler);
    socket.once('connect', connectHandler);
    return socket;
};
