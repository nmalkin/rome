all main.js: main.coffee
	coffee --compile $<

watch: main.coffee
	nodemon --exec "coffee --compile" --ext ".coffee" $<

clean:
	rm -f main.js
