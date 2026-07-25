// segment: server

// Serves the local PokeAPI fixtures so we never hit the live API.
//
//	go run ./cmd/serve-fixtures
//	curl http://localhost:9595/api/v2/pokemon/bulbasaur
package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	// Default to the fixtures directory the fetch script creates.
	// Pass a different path as an argument if you cloned api-data.
	fixtureDir := "fixtures/data"
	if len(os.Args) > 1 {
		fixtureDir = os.Args[1]
	}

	// `http.FileServer` serves static files from a directory. It maps
	// the request path directly to the filesystem, so a request for
	// /api/v2/pokemon/bulbasaur looks for fixtures/data/api/v2/pokemon/bulbasaur.
	// No routing needed because we wrote the fixture files without extensions.
	//
	// `http.ListenAndServe` blocks forever (or until it errors).
	// `log.Fatal` prints the error and exits if the server dies.
	address := ":9595"
	log.Printf("Serving %s on http://localhost%s/api/v2", fixtureDir, address)
	log.Fatal(http.ListenAndServe(address, http.FileServer(http.Dir(fixtureDir))))
}
// end: server
