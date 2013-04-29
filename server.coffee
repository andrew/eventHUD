express  = require 'express'
partials = require 'express-partials'
passport = require "passport"
mongoose = require 'mongoose'
resource = require 'express-resource'
forms    = require 'forms'
Lanyrd   = require 'lanyrd'

TwitterStrategy = require("passport-twitter").Strategy
Schema          = mongoose.Schema
fields          = forms.fields
validators      = forms.validators

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
app.use(express.methodOverride());

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

HUDSchema = new Schema(
  lanyrdURL: String
  slug: String
  year: String
  title: String
  subtitle: String
  html_description: String
  tagline: String
  has_speakers: String
  has_sessions: String
  has_attendees: String
  full_url: String
  venue_title: String
  venue_subtitle: String
  venue_latitude: String
  venue_longitude: String
  twitter_hash_tag: String
  twitter_account: String
  userID: Schema.Types.ObjectId
  created:
    type: Date
    default: Date.now
)

mongoose.connect "mongodb://localhost/eventhud"
mongoose.model "User", UserSchema
mongoose.model "HUD", HUDSchema 

User = mongoose.model("User")
HUD = mongoose.model("HUD")

# forms

HUDForm = forms.create(
  lanyrdURL: fields.string(label: 'Lanyrd Event URL')
)

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

ensureAuthenticated = (req, res, next) ->
  return next() if req.user?
  res.redirect "/"

# application routes

app.get "/", (req,res) ->
  if req.user
    res.redirect "huds/new"
  else
    res.render 'home/index',
      user: req.user

app.get "/huds/new", (req, res) ->
  ensureAuthenticated req, res, ->
    res.render 'huds/new',
      user: req.user
      form: HUDForm 

app.get "/huds/:id/edit", (req, res) ->
  HUD.findById req.params.id, (err, hud) ->
    if err
      res.send('not found', 404);
    else
      form = HUDForm.bind(hud)
      res.render "huds/edit",
        user: req.user
        hud: hud
        form: form

populate = (hud, cb) ->
  console.log hud.lanyrdURL
  console.log hud.lanyrdURL.match(/\d\/(.+?)[\/]/)
  console.log hud.lanyrdURL.match(/lanyrd.com\/(\d{4})\//)
  
  slug = hud.lanyrdURL.match(/\d\/(.+?)[\/]?$/)[1]
  year = hud.lanyrdURL.match(/lanyrd.com\/(\d{4})\//)[1]
  console.log(slug, year)
  Lanyrd.event slug, year, (err, resp, event)->
    console.log('lanyrd', err, event)
    hud.slug              = slug
    hud.year              = year
    hud.title             = event.title
    hud.subtitle          = event.subtitle
    hud.html_description  = event.html_description
    hud.tagline           = event.tagline
    hud.has_speakers      = event.has_speakers
    hud.has_sessions      = event.has_sessions
    hud.has_attendees     = event.has_attendees
    hud.full_url          = event.full_url
    hud.twitter_hash_tag  = event.twitter_hash_tag
    hud.twitter_account   = event.twitter_account
    hud.venue_title       = event.primary_venue?.title
    hud.venue_subtitle    = event.primary_venue?.subtitle
    hud.venue_latitude    = event.primary_venue?.latitude
    hud.venue_longitude   = event.primary_venue?.longitude
    cb(err, hud)

app.post "/huds", (req, res) ->
  HUDForm.handle req,
    success: (form) ->
      hud = new HUD(form.data)
      
      populate hud, (err, hud) ->
        if err
          res.render "huds/new",
            user: req.user
        else
          hud.save (err, hud) ->
            if err
              res.render "huds/new",
                user: req.user
            else
              res.redirect "huds/#{hud.id}"

    other: (form) ->
      console.log 'invalid'
      res.render "huds/new",
        form: form
        user: req.user

app.get "/huds/:id", (req, res) ->
  HUD.findById req.params.id, (err, hud) ->
    if err
      res.send('not found', 404);
    else
      res.render "huds/show",
        user: req.user
        hud: hud

app.put "/huds/:id", (req, res) ->
  HUD.findById req.params.id, (err, hud) ->
    if err
      res.send('not found', 404);
    else
      HUDForm.handle req,
        success: (form) ->
          populate hud, (err, hud) ->
            hud.save (err, hud) ->
              if err
                res.render "huds/edit",
                  user: req.user
                  hud: hud
                  form: form
              else
                res.redirect "huds/#{hud.id}"

        other: (form) ->
          console.log 'invalid'
          res.render "huds/new",
            form: form
            user: req.user

app.get "/huds/:id/view", (req, res) ->
  HUD.findById req.params.id, (err, hud) ->
    if err
      res.send('not found', 404);
    else      
      Lanyrd.attendees hud.slug, hud.year, (err, resp, attendees)->
        Lanyrd.speakers hud.slug, hud.year, (err, resp, speakers)->
          res.render 'events/show',
            hud: hud
            user: req.user
            layout: 'fullscreen'
            attendees: attendees
            speakers: speakers


# startup

port = process.env.PORT || 5000
app.listen port
console.log "Listening on Port '#{port}'"