# Tegola

Tegola is a high performance vector tile server delivering [Mapbox Vector Tiles](https://github.com/mapbox/vector-tile-spec) leveraging PostGIS as the data provider.

## Near term goals
- [X] Support for transcoding WKB to MVT.
- [x] Support for `/z/x/y` web mapping URL scheme.
- [x] Support for PostGIS data provider.

## Running Tegola
1. Download the appropriate binary of tegola for your platoform via the [release page](https://github.com/terranodo/tegola/releases).
2. Setup your config file and run. Tegola expects a `config.toml` to be in the same directory as the binary. You can set a different location for the `config.toml` using a command flag:

```
./tegola -config-file=/path/to/config.toml
```

## URL Scheme
Tegola uses the following URL scheme:

```
/maps/:map_name/:z/:x/:y
```

- `:map_name` is the name of the map as defined in the `config.toml` file.
- `:z` is the zoom level of the map.
- `:x` is the row of the tile at the zoom level.
- `:y` is the column of the tile at the zoom level.



## Configuration
The tegola config file uses the [TOML](https://github.com/toml-lang/toml) format. The following example shows how to configure a PostGIS data provider with two layers. The first layer includes a `tablename`, `geometry_field` and an `id_field`. The second layer uses a custom `sql` statement instead of the `tablename` property.

Under the `maps` section, map layers are associated with dataprovider layers and their `min_zoom` and `max_zoom` values are defined. Optionally, `custom_tags` can be setup which will be encoded into the layer. If the same tags are returned from a data provider, the dataprovider's values will take precidence.

```toml

[webserver]
port = ":9090"

# register data providers
[[providers]]
name = "test_postgis"	# provider name is referenced from map layers
type = "postgis"		# the type of data provider. currently only supports postgis
host = "localhost"		# postgis database host
port = 5432				# postgis database port
database = "tegola" 	# postgis database name
user = "tegola"			# postgis database user
password = ""			# postgis database password

	[[providers.layers]]
	name = "landuse" 					# will be encoded as the layer name in the tile
	tablename = "gis.zoning_base_3857" 	# sql or table_name are required
	geometry_fieldname = "geom"			# geom field. default is geom
	id_fieldname = "gid"				# geom id field. default is gid


	[[providers.layers]]
	name = "rivers" 					# will be encoded as the layer name in the tile
	geometry_fieldname = "geom"			# geom field. default is geom
	id_fieldname = "gid"				# geom id field. default is gid
	sql = """
		SELECT 
			gid,
			ST_AsBinary(geom) AS geom
		FROM
			gis.rivers
		WHERE
			geom && !BBOX!				
	"""

# maps are made up of layers
[[maps]]
name = "zoning"							# used in the URL to reference this map (/maps/:map_name)

	[[maps.layers]]
	provider_layer = "test_postgis.landuse"	# must match a data provider layer
	min_zoom = 12						# minimum zoom level to include this layer
	max_zoom = 16						# maximum zoom level to include this layer

		[maps.layers.default_tags]		# table of default tags to encode in the tile. SQL statements will override
		class = "park"

	[[maps.layers]]
	provider_layer = "test_postgis.rivers"	# must match a data provider layer
	min_zoom = 10						# minimum zoom level to include this layer
	max_zoom = 18						# maximum zoom level to include this layer


```


## Command flags
Tegola currently supports the following command flags:

- `config-file` - path to the config.toml file.
- `port` - port for the webserver to bind to. i.e. :8080
- `log-file` - path to write webserver access logs
- `log-format` - The format that the logger will log with. Available fields: 
  - `{{.Time}}` : The current Date Time in RFC 2822 format.
  - `{{.RequestIP}}` : The IP address of the the requester.
  - `{{.Z}}` : The Zoom level.
  - `{{.X}}` : The X Coordinate.
  - `{{.Y}}` : The Y Coordinate.

## Specifications
- [Well Known Binary (WKB)](http://edndoc.esri.com/arcsde/9.1/general_topics/wkb_representation.htm)
- [Mapbox Vector Tile (MVT) 2.1](https://github.com/mapbox/vector-tile-spec/tree/master/2.1)

## License
See [license](LICENSE.md) file in repo.
