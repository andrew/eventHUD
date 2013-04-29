express = require 'express'
partials = require 'express-partials'

app = express()

app.set('view engine', 'ejs')
app.set('views', __dirname + '/views');
app.use(express.static(__dirname + "/public/"))
app.use(express.bodyParser())
app.use(partials())

app.get "/", (req,res) ->
  res.render 'home/index', layout: 'layout'

port = process.env.PORT || 3000
app.listen port
console.log "Listening on Port '#{port}'"