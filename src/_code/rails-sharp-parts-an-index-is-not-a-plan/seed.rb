# frozen_string_literal: true

require "active_record"
require "securerandom"

# segment: db_config
DB_CONFIG = { adapter: "trilogy", database: "sharp_indexes", username: "root", host: "127.0.0.1" }.freeze

ActiveRecord::Base.establish_connection(DB_CONFIG.merge(database: nil))
ActiveRecord::Base.connection.execute("CREATE DATABASE IF NOT EXISTS sharp_indexes")
ActiveRecord::Base.establish_connection(DB_CONFIG)
ActiveRecord::Base.logger = Logger.new(File::NULL)
# end: db_config

# segment: schema
ActiveRecord::Schema.define do
  create_table :bookings, force: true do |t|
    t.bigint   :customer_id,  null: false
    t.bigint   :event_id,     null: false
    t.string   :status,       null: false, limit: 20
    t.string   :seat_section, null: false, limit: 20
    t.integer  :amount_cents, null: false
    t.string   :email,        null: false, limit: 120
    t.string   :confirmation, null: false, limit: 12
    t.string   :phone,        limit: 20
    t.datetime :created_at,   null: false, precision: 6
  end
end
# end: schema

# segment: model
class Booking < ActiveRecord::Base; end
# end: model

# segment: constants
ROWS     = Integer(ENV.fetch("ROWS", "500000"))
BATCH    = 5_000
CUST     = 50_000
EVENTS   = 2_000
DOMAINS  = %w[gmail.com yahoo.com hotmail.com proton.me example.org].freeze
SECTIONS = %w[orchestra mezzanine balcony box lawn].freeze
# end: constants

# segment: pick_status
def pick_status(roll)
  case roll
  when 0...90 then "confirmed"
  when 90...98 then "cancelled"
  else "pending"
  end
end
# end: pick_status

# segment: build_row
def build_row(index, base_time, span)
  customer_id  = 1 + SecureRandom.random_number(CUST)
  event_id     = 1 + SecureRandom.random_number(EVENTS)
  status       = pick_status(SecureRandom.random_number(100))
  section      = SECTIONS[SecureRandom.random_number(SECTIONS.length)]
  amount       = 1000 + SecureRandom.random_number(49000)
  email        = "user#{index}@#{DOMAINS[SecureRandom.random_number(DOMAINS.length)]}"
  confirmation = SecureRandom.alphanumeric(12).upcase
  phone        = "555#{format('%07d', SecureRandom.random_number(10_000_000))}"
  ts           = Time.at(base_time + SecureRandom.random_number(span)).utc
  created_at   = ts.strftime("%Y-%m-%d %H:%M:%S.%6N")

  "(#{customer_id},#{event_id},'#{status}','#{section}',#{amount}," \
    "'#{email}','#{confirmation}','#{phone}','#{created_at}')"
end
# end: build_row

# segment: seed_bookings
def seed_bookings(row_count: ROWS, batch_size: BATCH)
  conn = ActiveRecord::Base.connection

  conn.execute("SET autocommit=0")
  conn.execute("SET unique_checks=0")
  conn.execute("SET foreign_key_checks=0")

  base_time = Time.utc(2024, 1, 1).to_i
  span = 730 * 24 * 3600

  inserted = 0
  while inserted < row_count
    n = [batch_size, row_count - inserted].min
    values = Array.new(n) { |i| build_row(inserted + i, base_time, span) }.join(",")

    conn.execute("INSERT INTO bookings" \
      "(customer_id,event_id,status,seat_section,amount_cents,email,confirmation,phone,created_at)" \
      " VALUES #{values}")
    inserted += n
    if (inserted % 50_000).zero?
      conn.execute("COMMIT")
      print "\r  seeded #{inserted}/#{row_count}" if $stdout.tty?
    end
  end
  conn.execute("COMMIT")
  conn.execute("SET autocommit=1")
  conn.execute("ANALYZE TABLE bookings")
  inserted
end
# end: seed_bookings

if __FILE__ == $0
  t0 = Time.now
  seed_bookings
  puts
  count = Booking.count
  puts "rows: #{count}   seed time: #{(Time.now - t0).round(1)}s"
  puts "status distribution:"
  Booking.group(:status).count.sort_by { |_, c| -c }.each do |status, c|
    pct = (100.0 * c / count).round(1)
    puts "  #{status.ljust(10)} #{c.to_s.rjust(7)}  (#{pct}%)"
  end
end
