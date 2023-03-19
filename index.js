'use strict'

var express = require('express');

var app = express()

app.get('/', function(req, res){
  res.send('Hello World - From PearlThoughts (Using AWS ECR, ECS and terraform)');
});

/* istanbul ignore next */
if (!module.parent) {
  app.listen(8080);
  console.log('Express started on port 8080');
}
