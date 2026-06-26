# frozen_string_literal: true

require_relative "setup"

# segment: schema_columns
def schema_columns
  Note
    .columns
    .select { |c| c.name.include?("notable") || c.name == "id" }
    .map { |c| "#{c.name}: #{c.sql_type}" }
end
# => ["notable_type: varchar(255)", "notable_id: bigint"]
# end: schema_columns

# segment: schema_index
def schema_index
  ActiveRecord::Base.connection.indexes(:notes).map { |index|
    "#{index.name} on #{index.columns.inspect}"
  }
end
# => ["index_notes_on_notable on [\"notable_type\", \"notable_id\"]"]
# end: schema_index

# segment: schema_foreign_keys
def schema_foreign_keys
  ActiveRecord::Base.connection.foreign_keys(:notes)
end
# => []
# end: schema_foreign_keys

# segment: notes_share_id
def notes_share_id
  Note
    .order(:id)
    .map { |n| {id: n.id, notable_type: n.notable_type, notable_id: n.notable_id} }
end
# => All three notes have notable_id=1, distinguished only by notable_type
# end: notes_share_id

# segment: well_formed_find
def well_formed_find(event)
  Note.where(notable: event).to_sql
end
# => SELECT ... WHERE notable_type = 'Event' AND notable_id = 1
# end: well_formed_find

# segment: proxy_identity
def proxy_identity(proxy)
  {
    class: proxy.class,
    is_a_ar_base: proxy.is_a?(ActiveRecord::Base),
    kind_of_event: proxy.kind_of?(Event),
    responds_to_getobj: proxy.respond_to?(:__getobj__),
    wrapped_class: proxy.__getobj__.class
  }
end
# end: proxy_identity

# segment: proxy_find
def proxy_find(proxy)
  Note.where(notable: proxy).to_sql
end
# => SELECT ... WHERE notable_id = 1   (no type clause!)
# end: proxy_find

# segment: proxy_leak
def proxy_leak(event, proxy)
  {
    event_notes_count: event.notes.count,
    proxy_query_count: Note.where(notable: proxy).count,
    leaked_notes: Note.where(notable: proxy).order(:id).map { |n|
      {id: n.id, type: n.notable_type, body: n.body}
    }
  }
end
# end: proxy_leak

# segment: proxy_writes_fine
def proxy_writes_fine(proxy)
  # Writing through the proxy works: the association knows the real class.
  proxy.notes.create!(body: "written through proxy")
  new_note = proxy.notes.last
  {
    count: proxy.notes.count,
    type_is_correct: new_note.notable_type == "Event",
    body: new_note.body
  }
end
# end: proxy_writes_fine

# segment: fix_unwrap
def fix_unwrap(proxy)
  sql = Note.where(notable: proxy.__getobj__).to_sql
  count = Note.where(notable: proxy.__getobj__).count
  {sql:, count:}
end
# end: fix_unwrap

# segment: exclusive_notes_schema
def exclusive_notes_schema
  <<~MIGRATION
    create_table :exclusive_notes do |t|
      t.references :event, foreign_key: true
      t.references :order, foreign_key: true
      t.references :seat,  foreign_key: true
      t.text :body
      t.check_constraint(
        "(event_id IS NOT NULL) + (order_id IS NOT NULL) + (seat_id IS NOT NULL) = 1",
        name: "notes_exactly_one_owner"
      )
    end
  MIGRATION
end
# end: exclusive_notes_schema

# segment: exclusive_belongs_to
def exclusive_belongs_to_demo(event, order)
  results = []

  # One foreign key set, the others nil: passes the CHECK.
  results << try_create("one real owner") { ExclusiveNote.create!(event_id: event.id, body: "ok") }

  # Two foreign keys set: violates the exactly-one-owner CHECK.
  results << try_create("two owners") { ExclusiveNote.create!(event_id: event.id, order_id: order.id, body: "bad") }

  # No foreign keys set: also violates the CHECK.
  results << try_create("zero owners") { ExclusiveNote.create!(body: "bad") }

  # Foreign key pointing at a non-existent row: rejected by the FK constraint.
  results << try_create("ghost owner") { ExclusiveNote.create!(event_id: 9999, body: "bad") }

  results
end
# Output:
#   one real owner => accepted
#   two owners     => rejected by CHECK
#   zero owners    => rejected by CHECK
#   ghost owner    => rejected by FK

def try_create(label)
  yield
  "#{label} => accepted"
rescue ActiveRecord::StatementInvalid, ActiveRecord::CheckViolation => e
  reason = if e.message.downcase.include?("check")
    "rejected by CHECK"
  else
    "rejected by FK"
  end
  "#{label} => #{reason}"
end
# end: exclusive_belongs_to

# segment: explain_with_type
def explain_with_type
  Note.where(notable_type: "Event", notable_id: 1).explain.to_s
end
# end: explain_with_type

# segment: explain_without_type
def explain_without_type
  Note.where(notable_id: 1).explain.to_s
end
# end: explain_without_type

# segment: injected_type
def injected_type
  Note.new(notable_type: "Admin", notable_id: 1).notable
end
# => NameError: uninitialized constant Admin
# end: injected_type

# segment: type_confusion
def type_confusion(event)
  Note.new(notable_type: "Order", notable_id: event.id).notable
end
# => #<Order id: 1>
# end: type_confusion

# segment: repoint
def repoint(note)
  before = note.notable.class
  note.update!(notable_type: "Order")
  [before, note.reload.notable.class]
end
# => [Event, Order]
# end: repoint

# segment: join_through_notable
def join_through_notable
  Note.joins(:notable).to_sql
rescue ActiveRecord::EagerLoadPolymorphicError => e
  e.message
end
# => "Cannot eagerly load the polymorphic association :notable"
# end: join_through_notable

# segment: preload_fanout
def preload_fanout
  total = 0
  sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
    total += 1 unless payload[:name] == "SCHEMA"
  end
  Note.preload(:notable).to_a.each(&:notable)
  ActiveSupport::Notifications.unsubscribe(sub)
  total
end
# => 4 (one for notes, then one each for events, orders, seats)
# end: preload_fanout

# segment: orphaned_note
def orphaned_note
  doomed = Event.create!
  Note.create!(notable: doomed, body: "orphan")
  doomed.destroy
  note = Note.where(notable_type: "Event", notable_id: doomed.id).first
  {present: note.present?, notable: note&.notable}
end
# => {present: true, notable: nil}
# end: orphaned_note

# segment: stale_after_namespace
def stale_after_namespace(event)
  # Simulate: the class was "Event", now it's namespaced as "Calendar::Event"
  old_name = Event.polymorphic_name
  # After the move, the new class has a different polymorphic_name
  new_name = "Calendar::Event"
  # Old notes still say "Event", new queries ask for "Calendar::Event"
  old_count = Note.where(notable_type: old_name, notable_id: event.id).count
  new_count = Note.where(notable_type: new_name, notable_id: event.id).count
  {old_name:, new_name:, old_count:, new_count:}
end
# => old notes found under old name, zero under new name
# end: stale_after_namespace
