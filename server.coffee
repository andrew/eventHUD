express  = require 'express'
partials = require 'express-partials'
passport = require "passport"
mongoose = require 'mongoose'
resource = require 'express-resource'
forms    = require 'forms'

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
  name: String
  # userID: Schema.Types.ObjectId
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
  name: fields.string(required: true)
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

# application routes

app.get "/", (req,res) ->
  res.render 'home/index',
    user: req.user

app.get "/huds", (req,res) ->
  HUD.find {}, (err, huds) ->
    if err
      res.send('not found', 404);
    else
      res.render 'huds/index',
        user: req.user
        huds: huds

app.get "/huds/new", (req, res) ->
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

app.post "/huds", (req, res) ->
  HUDForm.handle req,
    success: (form) ->
      hud = new HUD(form.data)
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
          hud.name = form.data.name
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


# startup

port = process.env.PORT || 5000
app.listen port
console.log "Listening on Port '#{port}'"