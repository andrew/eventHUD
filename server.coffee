express = require 'express'
partials = require 'express-partials'
passport = require("passport")
TwitterStrategy = require("passport-twitter").Strategy

# express configuration

app = express()
app.set('view engine', 'ejs')
app.set('views', __dirname + '/views');
app.use(express.static(__dirname + "/public/"))
app.use(express.bodyParser())
app.use(partials())
app.use(express.cookieParser());
app.use(express.bodyParser());
app.use(express.session({ secret: 'keyboard cat' }));
app.use(passport.initialize());
app.use(passport.session());

# twitter oauth

twitterOauth = new TwitterStrategy
  consumerKey: process.env.TWITTER_CONSUMER_KEY
  consumerSecret: process.env.TWITTER_CONSUMER_SECRET
  callbackURL: "http://127.0.0.1:5000/auth/twitter/callback"
  (token, tokenSecret, profile, done) ->
    # find or create user here
    done()

passport.use twitterOauth

app.get '/auth/twitter', passport.authenticate('twitter')
app.get "/auth/twitter/callback", passport.authenticate("twitter", successRedirect: "/", failureRedirect: "/")

# application routes

app.get "/", (req,res) ->
  res.render 'home/index', layout: 'layout'

# startup

port = process.env.PORT || 5000
app.listen port
console.log "Listening on Port '#{port}'"