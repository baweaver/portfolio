# A Rubyist in Go Land: Article 01

Code for "Your First Pokémon API Client."

## Setup

Fetch the fixtures (not committed, ~4.6MB of JSON from PokeAPI's static mirror):

```sh
ruby fetch_fixtures.rb
```

Start the local server:

```sh
go run ./cmd/serve-fixtures
```

Run the clients:

```sh
POKEAPI_URL=http://localhost:9595/api/v2 go run ./cmd/pokemon bulbasaur
POKEAPI_URL=http://localhost:9595/api/v2 ruby pokemon.rb bulbasaur
```

## Checks

From the site root:

```sh
bin/gocheck rubyist-in-go-land-01
```
