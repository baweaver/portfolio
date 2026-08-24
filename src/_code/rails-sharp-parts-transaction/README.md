# Rails Sharp Parts: The Block Is Not the Transaction

## Running Tests

MySQL and PostgreSQL specs must be run separately because each establishes its own `ActiveRecord::Base` connection:

```bash
# MySQL specs (requires MySQL running on 127.0.0.1, root access)
bundle exec rspec transaction_spec.rb claims_spec.rb

# PostgreSQL specs (requires PostgreSQL running on 127.0.0.1)
bundle exec rspec transaction_pg_spec.rb

# RuboCop cop specs (no database required)
bundle exec rspec no_io_in_transactions_spec.rb
```

## Files

- `transaction.rb` — testable MySQL segments proving article claims
- `transaction_spec.rb` — behavioral specs for MySQL segments
- `claims_spec.rb` — claim-wrapped assertions for every article statement (MySQL)
- `transaction_pg.rb` — testable PostgreSQL segments proving PG-specific claims
- `transaction_pg_spec.rb` — claim-wrapped assertions for PG-specific behavior
- `illustrations.rb` — all segments the article renders via CodeBlock (not tested directly; behaviors proven by equivalent segments in transaction.rb)
- `no_io_in_transactions.rb` — custom RuboCop cop
- `no_io_in_transactions_spec.rb` — cop specs
