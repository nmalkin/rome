# SETTINGS
ROUNDS = 3

# GLOBALS
MAIN = '#sidebar'
OFFSCREEN = [0, 0]

# Use tiles from MapQuest; see: http://developer.mapquest.com/web/products/open/map
TILE_SETTINGS =
    attribution: "Map data © <a href=\"http://www.openstreetmap.org/\" target=\"_blank\">OpenStreetMap</a> contributors — Tiles courtesy of <a href=\"http://www.mapquest.com/\" target=\"_blank\">MapQuest</a>"
    subdomains: ["otile1", "otile2", "otile3", "otile4"]

TILE_LAYER_MAP = new L.TileLayer("http://{s}.mqcdn.com/tiles/1.0.0/map/{z}/{x}/{y}.jpg", TILE_SETTINGS)
TILE_LAYER_SAT = new L.TileLayer("http://{s}.mqcdn.com/tiles/1.0.0/sat/{z}/{x}/{y}.jpg", TILE_SETTINGS)
LAYERS = [TILE_LAYER_MAP, TILE_LAYER_SAT]

# Start centered on central Rome
START_BOUNDS = [[41.886751707869635, 12.471263408660887], [41.89435512030309, 12.495853900909424]]


# Resize sidebar and map container on load and on window resize
resize = ->
    viewHeight = $(window).height() - 40
    map = $("#map")
    map.width(map.parent().width()).height viewHeight
    $("#sidebar").height viewHeight

resize()
$(window).resize resize


# Initialize map
_map = new L.Map 'map',
    doubleClickZoom: false
_map.addLayer TILE_LAYER_MAP
_map.fitBounds START_BOUNDS

# Augment data with metadata
# (stored separately for convenience)
DATA = do ->
    data = []

    if GEODATA.type isnt 'FeatureCollection'
        alert 'Unexpected geodata. Things are about to break.'

    features = GEODATA.features
    for feature in features
        name = feature.properties.Name
        if name of METADATA
            metadata = METADATA[name]
            for property of metadata
                feature.properties[property] = metadata[property]
        data.push feature
    data

# Load landmark descriptions to sidebar on demand
placeTemplate = Handlebars.compile $('#template-place').html()
loadLocationDescription = (location) ->
    html = placeTemplate location.properties
    $(MAIN).html html

# Confirm with user if they're about to interrupt a game
# (Enabled during gameplay)
warnAboutExit = ->
    confirm "Your game state will be lost if your reload the page. Continue?"

# Store transient map features in this layer
_gameLayer = L.layerGroup().addTo _map

# Main game steps
game =
    start: ->
        # Find out if the user has played before
        points = localStorage.getItem 'best'
        returning = points isnt null

        # Load welcome screen
        template = Handlebars.compile $('#template-welcome').html()
        html = template
            returning: returning
            points: round2 points
        $(MAIN).html html

        # Enable start button
        $('#begin').click ->
            $('#map').css 'opacity', 1
            game.play()
    
    play: ->
        round = 0 # current round
        totalPoints = 0 # total number of points accumulated
        usedLocations = [] # indeces of locations already used in the game
        currentLocation = null # current landmark, full (metadata + geometry)
        lastLandmark = null # current landmark, on the mpa
        allowInfoScreen = false # allow users to click locations for description?

        playNextRound = ->
            round++
            currentLocation = nextLocation()
            loadLocationDescription currentLocation
            _map.on 'dblclick', registerGuess
            _map.addLayer guessMarker
        
        nextLocation = ->
            nextChoice = ->
                Math.floor Math.random() * DATA.length

            choice = nextChoice()
            while (choice in usedLocations) \
            or (DATA[choice]['geometry']['type'] isnt 'Polygon') # TODO: support for non-polygon types
                choice = nextChoice()

            usedLocations.push choice
            DATA[choice]

        registerGuess = (e) ->
            guessMarker.setLatLng e.latlng
            guessMarker.openPopup()

        finalizeGuess = ->
            _map.off 'dblclick', registerGuess
            guess = guessMarker.getLatLng()

            _map.removeLayer guessMarker
            permanentGuessMarker = new L.Marker(guess,
                draggable: false
            )
            permanentGuessMarker.bindPopup \
                "Your guess for the location of the #{currentLocation.properties.Name}"
            _gameLayer.addLayer permanentGuessMarker

            showResults guess

        resultsTemplate = Handlebars.compile $('#template-results').html()
        showResults = (guess) ->
            drawGroundTruth currentLocation

            # Draw a line connecting guess and actual location
            truthCenter = lastLandmark.getBounds().getCenter()
            connector = L.polyline [guess, truthCenter],
                color: 'red'
            connector.addTo _gameLayer

            # How far off was the guess?
            distance = getDistance guess, currentLocation
            if isNaN distance
                console.log guess, currentLocation, distance
                alert 'Internal error (distance NaN)'
                return
            # Create fake guess location to use Leaflet's built-in distance calculator.
            # (It takes care of converting degrees to meters.)
            meters = guess.distanceTo new L.LatLng(guess.lat + distance, guess.lng)

            # Consolidate results
            exact = distance is 0
            close = meters < 50
            points = meters
            totalPoints += meters

            # Render results
            html = resultsTemplate
                exact: exact
                close: close
                distance: Math.round meters
                points: round2 points
                total: round2 totalPoints
                place: currentLocation.properties.Name
                last: round == ROUNDS

            showResultsScreen = ->
                $(MAIN).html html

                $('#continue').on 'click',  ->
                    _map.off 'click', showResultsScreen
                    _gameLayer.removeLayer connector

                    if round >= ROUNDS
                        game.finish totalPoints
                    else
                        allowInfoScreen = false
                        playNextRound()

            allowInfoScreen = true
            _map.on 'click', showResultsScreen
            showResultsScreen()


        drawGroundTruth = (location) ->
            lastLandmark = L.geoJson(location,
                onEachFeature: processGeoFeature
            )
            do (currentLocation) ->
                lastLandmark.on 'click', ->
                    if allowInfoScreen
                        loadLocationDescription currentLocation

            _gameLayer.addLayer lastLandmark

        processGeoFeature = (feature, layer) ->
            type = feature.geometry.type
            if type is "Polygon"
                name = feature.properties.Name
                layer.bindPopup(name)

        getDistance = (guess, truth) ->
            point = [guess.lng, guess.lat]
            polygon = truth.geometry.coordinates[0]
            inside = pointInsidePolygon point, polygon
            if inside then 0 else
                distanceToPolygon point, polygon


        # Marker used to display guess location
        guessMarker = new L.Marker OFFSCREEN,
            draggable: true
            title: 'Your guess for the location'
        guessMarkerContent = $('<input type="button" id="final" class="btn btn-primary" value="Yes, this is my final answer" />')
        guessMarkerContent.click finalizeGuess
        guessMarker.bindPopup guessMarkerContent[0]


        # Start game
        playNextRound()

        $('.navbar .brand').on 'click', warnAboutExit


    finish: (score) ->
        best = localStorage.getItem 'best'
        returning = best isnt null

        message = if score == 0
            'Genius!'
        else if score < 10
            'Amazing!'
        else if score < 25
            'Excellent!'
        else if score < 50
            'Great job!'
        else if score < 75
            'Good job!'
        else if score < 100
            'Nicely done!'
        else
            'Results'

        finishTemplate = Handlebars.compile $('#template-finish').html()
        html = finishTemplate
            total: roundNumber score, 2
            returning: returning
            previous: roundNumber best, 2
            improved: score < best
            acknowledgment: message

        showEndScreen = ->
            $(MAIN).html html
            $('#repeat').click restartGame

        restartGame = ->
            _map.off 'click', showEndScreen
            _gameLayer.clearLayers()
            game.play()

        _map.on 'click', showEndScreen
        showEndScreen()


        if returning
            best = Math.min best, score
        else
            best = score
        localStorage.setItem 'best', best
        


        $('.navbar .brand').off 'click', warnAboutExit


# Ray-casting algorithm stolen from https://github.com/substack/point-in-polygon
# (original in JavaScript)
# Input points are expected to be arrays
pointInsidePolygon = (point, vs) ->
    # ray-casting algorithm based on
    # http://www.ecse.rpi.edu/Homepages/wrf/Research/Short_Notes/pnpoly.html
    x = point[0]
    y = point[1]
    inside = false
    i = 0
    j = vs.length - 1

    while i < vs.length
        xi = vs[i][0]
        yi = vs[i][1]
        xj = vs[j][0]
        yj = vs[j][1]
        intersect = ((yi > y) isnt (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
        inside = not inside    if intersect
        j = i++
    inside

# Distance to segment implementation
# stolen from: http://stackoverflow.com/a/1501725
sqr = (x) ->
    x * x
dist2 = (v, w) ->
    sqr(v[0] - w[0]) + sqr(v[1] - w[1])
distToSegmentSquared = (p, v, w) ->
    l2 = dist2(v, w)
    return dist2(p, v)    if l2 is 0
    t = ((p[0] - v[0]) * (w[0] - v[0]) + (p[1] - v[1]) * (w[1] - v[1])) / l2
    return dist2(p, v)    if t < 0
    return dist2(p, w)    if t > 1
    dist2 p,
        x: v[0] + t * (w[0] - v[0])
        y: v[1] + t * (w[1] - v[1])
distToSegment = (p, v, w) ->
    Math.sqrt distToSegmentSquared(p, v, w)


# Point = [x, y], Polygon = [[x,y], ...]
distanceToPolygon = (point, polygon) ->
    # Sometimes when we're dealing with precision like this, we get NaNs
    myMin = (a, b) ->
        if isNaN a
            b
        else if isNaN b
            a
        else
            Math.min a, b

    minimumDistance = Infinity
    minimumDistance = myMin minimumDistance,
        distToSegment(point, polygon[0], polygon[polygon.length-1])
    for v in [1...polygon.length]
        minimumDistance = myMin minimumDistance,
            distToSegment(point, polygon[v-1], polygon[v])
    
    minimumDistance

roundNumber = (num, dec) ->
    Math.round(num * Math.pow(10, dec)) / Math.pow(10, dec)
round2 = (num) ->
    roundNumber num, 2




game.start()

