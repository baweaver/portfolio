// Command pokemon-quick is the first Go draft from post 1: one file,
// the default HTTP client, everything in main. It stays in the repo so
// the diff to cmd/pokemon remains inspectable.
package main

import (
	"cmp"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"slices"
	"strings"
)

// segment: structs

// In Go you define the shape of your data with structs before you use
// it. There is no equivalent to a loose Hash; every field has a name
// and a type declared up front. The backtick annotations (called
// "struct tags") tell the JSON decoder which key in the JSON maps to
// which field. `json:"name"` means "fill this field from the JSON key
// called name."
//
// In Ruby you'd just parse into a Hash and dig through it. Go makes
// you name everything first, but in return the compiler catches typos
// and wrong types before the code ever runs.

// NamedResource is PokeAPI's NamedAPIResource: a name plus a URL
// pointing at the full record. It appears all over the schema in
// types, abilities, and stats, so we extract it once.
type NamedResource struct {
	Name string `json:"name"`
	URL  string `json:"url"`
}

// Each of these structs maps to one object in the JSON arrays.
// `[]TypeSlot` in the Pokemon struct below means "a slice (dynamic
// array) of TypeSlot values."
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

// Pokemon is the top-level response from GET /api/v2/pokemon/{name}.
// We only declare the fields we care about; the decoder silently
// ignores any JSON keys that don't have a matching struct field.
type Pokemon struct {
	ID        int           `json:"id"`
	Name      string        `json:"name"`
	Types     []TypeSlot    `json:"types"`
	Abilities []AbilitySlot `json:"abilities"`
	Stats     []StatLine    `json:"stats"`
}
// end: structs

// segment: main

// Go has no built-in `capitalize`, so you write one yourself.
// This only handles ASCII which is fine for Pokémon names.
// In Ruby: `name.capitalize`.
func capitalize(word string) string {
	if word == "" {
		return word
	}
	return strings.ToUpper(word[:1]) + word[1:]
}

func main() {
	// `os.Args` includes the program name at index 0 (unlike Ruby's
	// ARGV which starts at the first real argument).
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: pokemon-quick NAME")
		os.Exit(1)
	}

	// `cmp.Or` returns the first non-zero value. For strings the zero
	// value is "", so this works like `ENV.fetch("POKEAPI_URL", default)`.
	baseURL := cmp.Or(os.Getenv("POKEAPI_URL"), "https://pokeapi.co/api/v2")

	// `http.Get` uses Go's default HTTP client, which has NO timeout.
	// If the server hangs, this hangs forever. We fix this later.
	// The `(response, err)` return pair is Go's convention for fallible
	// operations. You must check `err` before touching `response`.
	response, err := http.Get(fmt.Sprintf("%s/pokemon/%s", baseURL, strings.ToLower(os.Args[1])))
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	// `defer` is Go's `ensure`. It runs when the function exits,
	// regardless of how. We need it because the response body is an
	// open connection that leaks if we forget to close it.
	//
	// The `func() { _ = ... }()` wrapper is because Go's `errcheck`
	// linter complains if you ignore the error from `Close()`. The
	// `_ =` explicitly discards it, which tells the linter "yes I know
	// this returns an error, I'm choosing to ignore it here because
	// there's nothing useful to do with a close error on a read body."
	defer func() { _ = response.Body.Close() }()

	if response.StatusCode != http.StatusOK {
		fmt.Fprintf(os.Stderr, "no Pokémon named %q (%s)\n", os.Args[1], response.Status)
		os.Exit(1)
	}

	// `json.NewDecoder` reads JSON from the response body stream and
	// `Decode(&pokemon)` fills our struct fields using the `json:""`
	// tags we defined above. The `&` passes a pointer so the decoder
	// writes into our variable rather than a copy.
	// In Ruby this whole step is `JSON.parse(body, symbolize_names: true)`.
	var pokemon Pokemon
	if err := json.NewDecoder(response.Body).Decode(&pokemon); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
// end: main

	// segment: display

	// `slices.SortFunc` sorts a slice in-place using a comparison
	// function you provide. In Ruby you'd write `sort_by { _1.slot }`
	// or use `<=>` in a sort block. Go does not have `<=>` as an
	// operator, so the `cmp` package fills that role.
	//
	// `cmp.Compare(a, b)` takes two ordered values and returns:
	//   -1 if a < b
	//    0 if a == b
	//   +1 if a > b
	//
	// This is the same contract as Ruby's `<=>`. The function you pass
	// to `SortFunc` receives two elements and returns negative (left
	// first), zero (equal), or positive (right first).
	//
	// We sort by `Slot` so the primary type (slot 1) prints before the
	// secondary type (slot 2).
	slices.SortFunc(pokemon.Types, func(left, right TypeSlot) int {
		return cmp.Compare(left.Slot, right.Slot)
	})

	// `make([]string, n)` allocates a string slice of length n, all
	// empty strings. We fill it by walking the sorted types and pulling
	// each name out.
	//
	// In Ruby this would be:
	//   pokemon.types.map { _1.dig(:type, :name) }
	//
	// Go has no `map` equivalent in the standard library, you write the
	// loop. The tradeoff is that you always know exactly what's
	// happening and what type you're working with at each step.
	typeNames := make([]string, len(pokemon.Types))
	for position, slot := range pokemon.Types {
		typeNames[position] = slot.Type.Name
	}

	// Same pattern for abilities: allocate, loop, extract.
	abilityNames := make([]string, len(pokemon.Abilities))
	for position, slot := range pokemon.Abilities {
		abilityNames[position] = slot.Ability.Name
	}

	// `fmt.Printf` works like C's `printf` or Ruby's `format`/`sprintf`.
	// `%04d` pads the ID to 4 digits with leading zeros.
	// `strings.Join` is the equivalent of `Array#join` in Ruby.
	fmt.Printf("#%04d %s\n", pokemon.ID, capitalize(pokemon.Name))
	fmt.Printf("Types:     %s\n", strings.Join(typeNames, " / "))
	fmt.Printf("Abilities: %s\n\n", strings.Join(abilityNames, ", "))

	// Sort stats descending by base value. Note `right.BaseStat` comes
	// first in `cmp.Compare`, which reverses the order. In Ruby you'd
	// write `sort_by(&:last).reverse_each` or `sort_by { -_1.last }`.
	// Go has no reverse sort shorthand, you swap the arguments.
	slices.SortFunc(pokemon.Stats, func(left, right StatLine) int {
		return cmp.Compare(right.BaseStat, left.BaseStat)
	})

	// `%-16s` left-aligns the stat name in a 16-character field.
	// `%3d` right-aligns the number in 3 characters.
	// `strings.Repeat("█", n)` is the equivalent of `"█" * n` in Ruby.
	for _, line := range pokemon.Stats {
		fmt.Printf("%-16s %3d %s\n", line.Stat.Name, line.BaseStat, strings.Repeat("█", line.BaseStat/5))
	}
	// end: display
}
