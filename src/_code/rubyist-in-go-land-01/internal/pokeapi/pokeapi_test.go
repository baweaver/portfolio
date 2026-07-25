package pokeapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func bulbasaurJSON() []byte {
	pokemon := Pokemon{
		ID:   1,
		Name: "bulbasaur",
		Types: []TypeSlot{
			{Slot: 1, Type: NamedResource{Name: "grass", URL: "https://pokeapi.co/api/v2/type/12/"}},
			{Slot: 2, Type: NamedResource{Name: "poison", URL: "https://pokeapi.co/api/v2/type/4/"}},
		},
		Abilities: []AbilitySlot{
			{Ability: NamedResource{Name: "overgrow", URL: "https://pokeapi.co/api/v2/ability/65/"}, IsHidden: false},
			{Ability: NamedResource{Name: "chlorophyll", URL: "https://pokeapi.co/api/v2/ability/34/"}, IsHidden: true},
		},
		Stats: []StatLine{
			{BaseStat: 45, Stat: NamedResource{Name: "hp", URL: "https://pokeapi.co/api/v2/stat/1/"}},
			{BaseStat: 49, Stat: NamedResource{Name: "attack", URL: "https://pokeapi.co/api/v2/stat/2/"}},
		},
	}
	data, _ := json.Marshal(pokemon)
	return data
}

func TestNew_DefaultBaseURL(t *testing.T) {
	client := New("")
	if client.baseURL != DefaultBaseURL {
		t.Errorf("expected %s, got %s", DefaultBaseURL, client.baseURL)
	}
}

func TestNew_CustomBaseURL(t *testing.T) {
	client := New("http://localhost:9595/api/v2/")
	if client.baseURL != "http://localhost:9595/api/v2" {
		t.Errorf("expected trailing slash trimmed, got %s", client.baseURL)
	}
}

func TestNew_Timeout(t *testing.T) {
	client := New("")
	if client.httpClient.Timeout != 10*time.Second {
		t.Errorf("expected 10s timeout, got %v", client.httpClient.Timeout)
	}
}

func TestPokemon_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/pokemon/bulbasaur" {
			t.Errorf("unexpected path: %s", r.URL.Path)
		}
		w.WriteHeader(http.StatusOK)
		// `_, _ =` discards the (int, error) return from Write.
		// In test handlers we don't care about write errors since
		// the test will fail on the client side if data is missing.
		// The linter requires us to acknowledge the return values.
		_, _ = w.Write(bulbasaurJSON())
	}))
	defer server.Close()

	client := New(server.URL)
	pokemon, err := client.Pokemon(context.Background(), "bulbasaur")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if pokemon.ID != 1 {
		t.Errorf("expected ID 1, got %d", pokemon.ID)
	}
	if pokemon.Name != "bulbasaur" {
		t.Errorf("expected name bulbasaur, got %s", pokemon.Name)
	}
	if len(pokemon.Types) != 2 {
		t.Errorf("expected 2 types, got %d", len(pokemon.Types))
	}
	if len(pokemon.Abilities) != 2 {
		t.Errorf("expected 2 abilities, got %d", len(pokemon.Abilities))
	}
}

func TestPokemon_LowercasesName(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/pokemon/pikachu" {
			t.Errorf("expected lowercased path, got %s", r.URL.Path)
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(bulbasaurJSON())
	}))
	defer server.Close()

	client := New(server.URL)
	_, err := client.Pokemon(context.Background(), "PIKACHU")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestPokemon_NotFound(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	client := New(server.URL)
	_, err := client.Pokemon(context.Background(), "missingno")
	if err == nil {
		t.Fatal("expected error for 404, got nil")
	}
	expected := `no Pokémon named "missingno" (404 Not Found)`
	if err.Error() != expected {
		t.Errorf("expected %q, got %q", expected, err.Error())
	}
}

func TestPokemon_BadJSON(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("not json"))
	}))
	defer server.Close()

	client := New(server.URL)
	_, err := client.Pokemon(context.Background(), "bulbasaur")
	if err == nil {
		t.Fatal("expected error for bad JSON, got nil")
	}
}

func TestPokemon_NetworkError(t *testing.T) {
	client := New("http://127.0.0.1:1") // nothing listening
	_, err := client.Pokemon(context.Background(), "bulbasaur")
	if err == nil {
		t.Fatal("expected error for network failure, got nil")
	}
}

func TestPokemon_ContextCancellation(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(5 * time.Second)
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	client := New(server.URL)
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()

	_, err := client.Pokemon(ctx, "bulbasaur")
	if err == nil {
		t.Fatal("expected timeout error, got nil")
	}
}

func TestPokemon_InvalidBaseURL(t *testing.T) {
	client := New("://bad url")
	_, err := client.Pokemon(context.Background(), "bulbasaur")
	if err == nil {
		t.Fatal("expected error for invalid URL, got nil")
	}
}
