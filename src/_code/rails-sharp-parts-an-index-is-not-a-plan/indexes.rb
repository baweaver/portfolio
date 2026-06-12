# frozen_string_literal: true

require_relative "seed"

# segment: opening_example
def opening_migration
  ActiveRecord::Base.connection.add_index(:bookings, :customer_id, name: :idx_customer)
end
# end: opening_example

# segment: add_index_status
def add_status_index
  ActiveRecord::Base.connection.add_index(:bookings, :status, name: :idx_status)
end
# end: add_index_status

# segment: add_index_composite_esc
def add_composite_esc_index
  ActiveRecord::Base.connection.add_index(:bookings, [:event_id, :status, :created_at], name: :idx_esc)
end
# end: add_index_composite_esc

# segment: add_index_created_at
def add_created_at_index
  ActiveRecord::Base.connection.add_index(:bookings, :created_at, name: :idx_created)
end
# end: add_index_created_at

# segment: date_function_query
def date_function_query
  Booking.where("DATE(created_at) = ?", "2024-06-15")
end
# end: date_function_query

# segment: half_open_range_query
def half_open_range_query
  Booking.where("created_at >= ? AND created_at < ?", "2024-06-15", "2024-06-16")
end
# end: half_open_range_query

# segment: add_index_email
def add_email_index
  ActiveRecord::Base.connection.add_index(:bookings, :email, name: :idx_email)
end
# end: add_index_email

# segment: lower_email_query
def lower_email_query(email)
  Booking.where("LOWER(email) = ?", email.downcase)
end
# end: lower_email_query

# segment: functional_index
def add_functional_email_index
  ActiveRecord::Base.connection.execute("CREATE INDEX idx_lower_email ON bookings ((LOWER(email)))")
end
# end: functional_index

# segment: add_index_confirmation
def add_confirmation_index
  ActiveRecord::Base.connection.add_index(:bookings, :confirmation, name: :idx_conf)
end
# end: add_index_confirmation

# segment: like_queries
def like_trailing(prefix)
  Booking.where("confirmation LIKE ?", "#{prefix}%")
end

def like_leading(suffix)
  Booking.where("confirmation LIKE ?", "%#{suffix}")
end
# end: like_queries

# segment: add_index_phone
def add_phone_index
  ActiveRecord::Base.connection.add_index(:bookings, :phone, name: :idx_phone)
end
# end: add_index_phone

# segment: phone_queries
def phone_string_query(phone)
  Booking.where(phone: phone)
end

def phone_numeric_query(phone)
  # Rails typecasts bind params to strings for VARCHAR columns, making it
  # nearly impossible to trigger this mismatch through ActiveRecord alone.
  # In production this surfaces in hand-written SQL or cross-system joins.
  # We test it via a raw EXPLAIN to prove the optimizer behavior.
  ActiveRecord::Base.connection.select_all(
    "EXPLAIN SELECT * FROM bookings WHERE phone = #{Integer(phone)}"
  )
end
# end: phone_queries

# segment: add_index_covering
def add_covering_index
  ActiveRecord::Base.connection.add_index(:bookings, [:customer_id, :created_at], name: :idx_cu_cr)
end
# end: add_index_covering

# segment: three_star_query
def three_star_query(customer_id)
  Booking
    .where(customer_id: customer_id)
    .where("created_at >= ?", "2024-06-01")
    .order(:created_at)
    .select(:id, :created_at)
end
# end: three_star_query

# segment: three_star_index
def add_three_star_index
  ActiveRecord::Base.connection.add_index(:bookings, [:customer_id, :created_at], name: :idx_three_star)
end
# end: three_star_index

# segment: redundant_indexes
def add_redundant_indexes
  ActiveRecord::Base.connection.add_index(:bookings, :customer_id, name: :idx_cust)
  ActiveRecord::Base.connection.add_index(:bookings, [:customer_id, :created_at], name: :idx_cust_created)
end
# end: redundant_indexes

# segment: redundant_sys_query
def redundant_index_check
  ActiveRecord::Base.connection.execute(
    "SELECT redundant_index_name, dominant_index_name " \
    "FROM sys.schema_redundant_indexes WHERE table_name = 'bookings'"
  )
end
# end: redundant_sys_query

# segment: explain_example
def explain_query(customer_id)
  Booking.where(customer_id: customer_id).order(:created_at).explain.inspect
end

def explain_analyze_query(customer_id)
  Booking.where(customer_id: customer_id).order(:created_at).explain(:analyze).inspect
end
# end: explain_example

# segment: query_log_tags
def query_log_tags_config(config)
  config.active_record.query_log_tags_enabled = true
  config.active_record.query_log_tags = [:application, :controller, :action, :source_location]
end
# end: query_log_tags

# segment: invisible_indexes
def make_index_invisible(index_name)
  quoted = ActiveRecord::Base.connection.quote_column_name(index_name)
  ActiveRecord::Base.connection.execute("ALTER TABLE bookings ALTER INDEX #{quoted} INVISIBLE")
end

def make_index_visible(index_name)
  quoted = ActiveRecord::Base.connection.quote_column_name(index_name)
  ActiveRecord::Base.connection.execute("ALTER TABLE bookings ALTER INDEX #{quoted} VISIBLE")
end
# end: invisible_indexes

# segment: helpers
def drop_secondary_indexes
  ActiveRecord::Base.connection.indexes(:bookings).each do |idx|
    ActiveRecord::Base.connection.remove_index(:bookings, name: idx.name)
  end
end

def with_indexes(*specs)
  drop_secondary_indexes
  specs.each do |name, columns, **opts|
    ActiveRecord::Base.connection.add_index(:bookings, columns, name: name, **opts)
  end
  yield
ensure
  drop_secondary_indexes
end

def fixtures
  @fixtures ||= {
    customer_id: Booking.group(:customer_id).count.max_by { |_, v| v }.first,
    event_id: Booking.group(:event_id).count.max_by { |_, v| v }.first,
    confirmation: Booking.first!.confirmation,
    email: Booking.first!.email,
    phone: Booking.first!.phone
  }
end

def ensure_seeded!
  return if Booking.count == 500_000

  seed_bookings(row_count: 500_000)
end
# end: helpers
