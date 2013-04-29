express = require 'express'
partials = require 'express-partials'
passport = require "passport"
mongoose = require 'mongoose'
TwitterStrategy = require("passport-twitter").Strategy
Schema = mongoose.Schema

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

# mongo config

UserSchema = new Schema(
  provider: String
  uid: String
  name: String
  image: String
  created:
    type: Date
    default: Date.now
)

mongoose.connect "mongodb://localhost/eventhud"
mongoose.model "User", UserSchema

User = mongoose.model("User")

# twitter oauth

twitterOauth = new TwitterStrategy
  consumerKey: process.env.TWITTER_CONSUMER_KEY
  consumerSecret: process.env.TWITTER_CONSUMER_SECRET
  callbackURL: "http://127.0.0.1:5000/auth/twitter/callback"
  (token, tokenSecret, profile, done) ->
    User.findOne
      uid: profile.id
    , (err, user) ->
      if user
        done null, user
      else
        user = new User()
        user.provider = "twitter"
        user.uid = profile.id
        user.name = profile.displayName
        user.image = profile._json.profile_image_url
        user.save (err) ->
          throw err  if err
          done null, user

passport.serializeUser (user, done) ->
  done null, user.uid

passport.deserializeUser (id, done) ->
  User.findOne
    uid: id
  , (err, user) ->
    done err, user

passport.use twitterOauth

app.get '/auth/twitter', passport.authenticate('twitter')
app.get "/auth/twitter/callback", passport.authenticate("twitter", successRedirect: "/?success", failureRedirect: "/?fail")

app.get "/logout", (req, res) ->
  req.logout()
  res.redirect "/"

# application routes

app.get "/", (req,res) ->
  res.render 'home/index',
    layout: 'layout'
    user: req.user

# startup

port = process.env.PORT || 5000
app.listen port
console.log "Listening on Port '#{port}'"