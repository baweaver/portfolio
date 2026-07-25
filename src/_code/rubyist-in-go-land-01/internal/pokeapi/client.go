// Package pokeapi is a small client for PokeAPI (https://pokeapi.co),
// or any mirror of it, covering only what this series needs so far.
package pokeapi

import (
	"net/http"
	"strings"
	"time"
)

// DefaultBaseURL is the live API. Point New at a local mirror instead
// whenever you can; PokeAPI's fair use policy asks clients to keep
// request volume down.
const DefaultBaseURL = "https://pokeapi.co/api/v2"

// segment: client

// `Client` is a struct that holds the configuration for talking to
// PokeAPI. In Ruby you might make a class with `initialize` storing
// `@base_url` and `@http`. Go uses structs with fields instead of
// instance variables. Lowercase field names (`baseURL`, `httpClient`)
// are private to this package, like Ruby's `private attr_reader`.
type Client struct {
	baseURL    string
	httpClient *http.Client
}

// `New` is the conventional Go constructor name (there are no special
// constructor methods like `initialize`). It returns a pointer to a
// Client (`*Client`). The `&Client{...}` syntax allocates a Client
// and returns its address.
//
// The key difference from the quick draft: we build our own
// `http.Client` with an explicit 10-second timeout. The default
// client that `http.Get` uses has NO timeout at all, which means a
// hung server will block forever. Ruby's `Net::HTTP` defaults to 60
// seconds for both open and read; Go defaults to infinity.
func New(baseURL string) *Client {
	if baseURL == "" {
		baseURL = DefaultBaseURL
	}

	return &Client{
		baseURL: strings.TrimRight(baseURL, "/"),
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}
// end: client
