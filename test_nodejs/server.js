/**
 * server.js
 *
 * Purpose:
 *
 * Description:
 *
 * History:
 *    2019/11/20, Created by jumperchen
 *
 * Copyright (C) 2019 Potix Corporation. All Rights Reserved.
 */
'use strict';
var http = require('http').createServer();
var io = require('socket.io')(http);

io.on('connection', function(socket){
    console.log('connection default namespace');
    socket.on('msg', function (data, ack) {
        if (ack != null) {
            ack(1, 2, 3);
        }
        console.log(`data from default => ${data}`);
        socket.emit('fromServer', `${data}`);
    });
});

http.listen(3000, function(){
    console.log('listening on *:3000');
});

