package pokeapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
)

// NamedResource is PokeAPI's NamedAPIResource: a name plus a URL
// pointing at the full record. It appears all over the schema.
type NamedResource struct {
	Name string `json:"name"`
	URL  string `json:"url"`
}

type TypeSlot struct {
	Slot int           `json:"slot"`
	Type NamedResource `json:"type"`
}

type AbilitySlot struct {
	Ability  NamedResource `json:"ability"`
	IsHidden bool          `json:"is_hidden"`
}

type StatLine struct {
	BaseStat int           `json:"base_stat"`
	Stat     NamedResource `json:"stat"`
}

type Pokemon struct {
	ID        int           `json:"id"`
	Name      string        `json:"name"`
	Types     []TypeSlot    `json:"types"`
	Abilities []AbilitySlot `json:"abilities"`
	Stats     []StatLine    `json:"stats"`
}

// segment: fetch

// `Pokemon` is a method on `*Client` (the `(client *Client)` part is
// called a "receiver", Go's version of `self`). It takes a
// `context.Context` and a name, and returns either a `Pokemon` value
// or an error. Go functions can return multiple values; the
// convention for fallible operations is `(result, error)`.
//
// `context.Context` carries deadlines and cancellation signals. When
// the client's 10-second timeout fires, the context is cancelled and
// the request aborts. In Ruby you'd set `Net::HTTP#read_timeout`;
// Go threads the deadline through every layer via context.
func (client *Client) Pokemon(ctx context.Context, name string) (Pokemon, error) {
	requestURL := fmt.Sprintf("%s/pokemon/%s", client.baseURL, strings.ToLower(name))

	// `http.NewRequestWithContext` builds a request and attaches the
	// context to it. This is how the timeout reaches the network call.
	// If the URL is malformed this returns an error immediately.
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, requestURL, nil)
	if err != nil {
		return Pokemon{}, fmt.Errorf("building request for %s: %w", name, err)
	}

	// `client.httpClient.Do(request)` sends the request using our
	// configured client (with the timeout). Unlike `http.Get` which
	// uses the global default client, this respects our deadline.
	response, err := client.httpClient.Do(request)
	if err != nil {
		// `%w` wraps the original error so callers can inspect it with
		// `errors.Is` or `errors.As` later. This is Go's version of
		// exception chaining (like Ruby's `cause`).
		return Pokemon{}, fmt.Errorf("fetching %s: %w", name, err)
	}
	// Explicitly discard the Close error with `_ =` to satisfy the
	// errcheck linter. A close error on a response we already read
	// from has no recovery path, but the linter wants proof you
	// thought about it.
	defer func() { _ = response.Body.Close() }()

	if response.StatusCode != http.StatusOK {
		return Pokemon{}, fmt.Errorf("no Pokémon named %q (%s)", name, response.Status)
	}

	var pokemon Pokemon
	if err := json.NewDecoder(response.Body).Decode(&pokemon); err != nil {
		return Pokemon{}, fmt.Errorf("decoding %s: %w", name, err)
	}

	return pokemon, nil
}
// end: fetch
