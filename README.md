Where in Rome?
==============
This is a game designed to test your knowledge of the Eternal City by asking you to place Ancient Roman landmarks on a modern map. It is a static web application; no server is necessary to run it, just open `index.html`.

The locations of the monuments come from the map on page 191 of ["The City of Rome: From Republic to Empire"](http://www.jstor.org/stable/301291) in _The Journal of Roman Studies_, Vol. 82 (1992) by John R. Patterson. The map was overlaid on Google Earth satellite imagery, and the locations were transferred (manually) and saved as KML features, subsequently being converted to GeoJSON.

The application uses [Leaflet](http://leafletjs.com/) to display the data over [OpenStreetMap](http://www.openstreetmap.org/), with tiles served by [MapQuest](http://developer.mapquest.com/web/products/open/map). It also uses [Bootstrap](http://twitter.github.io/bootstrap/), [Handlebars](http://handlebarsjs.com/), and [jQuery](http://jquery.com/).
