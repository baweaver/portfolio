// Command pokemon fetches one Pokemon from PokeAPI (or a local mirror)
// and prints its profile: number, name, types, abilities, and base stats.
//
//	POKEAPI_URL=http://localhost:9595/api/v2 go run ./cmd/pokemon bulbasaur
package main

import (
	"cmp"
	"context"
	"fmt"
	"os"
	"slices"
	"strings"

	"github.com/baweaver/rubyist-in-go-land/internal/pokeapi"
)

// segment: run

// `main` does one thing: call `run` and translate its error into an
// exit code. This pattern keeps `main` trivial and makes the real
// logic testable (you can call `run` from a test without triggering
// `os.Exit`). In Ruby you'd put everything in the script body; Go
// convention separates "exit policy" from "program logic."
func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

// `run` returns an error instead of calling `os.Exit` directly.
// Every failure path returns an error with context about what went
// wrong, and `main` decides what to do with it (here: print and exit 1).
// In Ruby you'd `abort` or `raise`; Go makes the error a return value
// you pass back up the call stack.
func run(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("usage: pokemon NAME")
	}

	// `pokeapi.New` is our client constructor from internal/pokeapi.
	// The `internal/` directory means only code inside this module can
	// import it. Other Go modules cannot reach in, giving us a private
	// API boundary without access modifiers on every method.
	client := pokeapi.New(os.Getenv("POKEAPI_URL"))

	// `context.Background()` is the root context with no deadline of
	// its own. The client's 10-second timeout still applies because
	// `New` configured it on the `http.Client`. In later posts we'll
	// pass contexts with tighter deadlines or cancellation signals.
	pokemon, err := client.Pokemon(context.Background(), args[0])
	if err != nil {
		return err
	}

	printProfile(pokemon)
	return nil
}
// end: run

// segment: print
func printProfile(pokemon pokeapi.Pokemon) {
	slices.SortFunc(pokemon.Types, func(left, right pokeapi.TypeSlot) int {
		return cmp.Compare(left.Slot, right.Slot)
	})
	typeNames := make([]string, len(pokemon.Types))
	for position, slot := range pokemon.Types {
		typeNames[position] = slot.Type.Name
	}

	abilityNames := make([]string, len(pokemon.Abilities))
	for position, slot := range pokemon.Abilities {
		abilityNames[position] = slot.Ability.Name
	}

	fmt.Printf("#%04d %s\n", pokemon.ID, capitalize(pokemon.Name))
	fmt.Printf("Types:     %s\n", strings.Join(typeNames, " / "))
	fmt.Printf("Abilities: %s\n\n", strings.Join(abilityNames, ", "))

	slices.SortFunc(pokemon.Stats, func(left, right pokeapi.StatLine) int {
		return cmp.Compare(right.BaseStat, left.BaseStat)
	})
	for _, line := range pokemon.Stats {
		fmt.Printf("%-16s %3d %s\n", line.Stat.Name, line.BaseStat, strings.Repeat("█", line.BaseStat/5))
	}
}

func capitalize(word string) string {
	if word == "" {
		return word
	}
	return strings.ToUpper(word[:1]) + word[1:]
}
// end: print
