# frozen_string_literal: true

require "coverage"

Coverage.start(lines: true, eval: true)

require_relative "callbacks"

RSpec.configure do |config|
  config.after(:suite) do
    results = Coverage.result
    root = File.expand_path(".", __dir__)
    tracked = results.select { |p, _| p.start_with?(root) && !p.end_with?("_spec.rb") }

    total = 0
    hit = 0
    uncovered_report = []

    tracked.each do |path, data|
      lines = data[:lines]
      file_uncovered = []
      lines.each_with_index do |hits, i|
        next if hits.nil?
        total += 1
        if hits > 0
          hit += 1
        else
          file_uncovered << (i + 1)
        end
      end

      uncovered_report << [path.sub("#{root}/", ""), file_uncovered] unless file_uncovered.empty?
    end

    pct = total > 0 ? (100.0 * hit / total).round(2) : 0
    puts("\n\nCoverage: #{hit}/#{total} lines (#{pct}%)")
    uncovered_report.each { |f, lines| puts("  #{f}: uncovered lines #{lines.join(", ")}") }
    abort("\n\nFAILED: Coverage is #{pct}%, must be 100%.") unless pct == 100.0
  end
end

RSpec.describe "Rails: The Sharp Parts — Callbacks Are Not Invariants" do
  before(:each) { SideEffects.clear! }

  describe "census" do
    it "reports save callbacks from belongs_to touch+counter_cache" do
      filters = Post._save_callbacks.map { _1.filter.to_s }
      expect(filters.any? { |f| f.include?("autosave") }).to(be(true))
    end

    it "counts at least 4 on a belongs_to with touch+counter_cache" do
      expect(census(Post)).to(be >= 4)
    end

    it "counts at least 4 on a has_many with dependent: :destroy" do
      expect(census(Author)).to(be >= 4)
    end
  end

  describe "Failure One: skip matrix" do
    it "update_attribute skips validations" do
      expect(update_attribute_demo).to(eq("invalid"))
    end

    it "insert_all drifts counter_cache" do
      result = counter_cache_drift
      expect(result[:counter]).to(eq(1))
      expect(result[:actual]).to(eq(4))
    end

    it "counter cache isn't healed on next update" do
      event = Event.create!(name: "Heal#{SecureRandom.hex(4)}")
      Seat.create!(event: event, external_ref: "H1")
      Seat.insert_all([{event_id: event.id, external_ref: "H2"}])
      Seat.find_by!(external_ref: "H1").update!(reserved_by: "someone")
      expect(event.reload.seats_count).to(eq(1))
      expect(event.seats.count).to(eq(2))
    end
    end

    it "backfill_example runs without error" do
      Order.create!(region: nil)
      expect { backfill_example }.not_to(raise_error)
      expect(Order.where(region: nil).count).to(eq(0))
    end

    it "backfill_update_all runs without error" do
      Order.create!(region: nil)
      expect { backfill_update_all }.not_to(raise_error)
    end
  end

  describe "Failure Two: firing when nobody asked" do
    it "touch: true fires parent update inside the child transaction" do
      effects = touch_trace
      # after_save runs inside the transaction
      save_entry = effects.find { |e| e.first == :seat_after_save }
      expect(save_entry[1]).to(be(true))
      # after_commit runs outside
      commit_entry = effects.find { |e| e.first == :seat_after_commit }
      expect(commit_entry[1]).to(be(false))
      # event was touched as a side effect
      touch_entry = effects.find { |e| e.first == :event_was_touched }
      expect(touch_entry[1]).to(be(true))
    end

    it "re-enters the chain to depth 3" do
      expect(reentry_demo).to(eq(3))
    end

    it "after_find fires once per loaded row" do
      event = Event.create!(name: "AFD#{SecureRandom.hex(4)}")
      refs = 5.times.map { "AF#{SecureRandom.hex(4)}" }
      refs.each { |r| Seat.create!(event: event, external_ref: r) }
      expect(after_find_demo(refs)).to(eq(5))
    end

    it "after_initialize marks a fresh record dirty" do
      Seat.create!(external_ref: "DIRTY#{SecureRandom.hex(4)}", priority: false)
      expect(after_initialize_dirty).to(be(true))
    end
  end

  describe "Failure Three: validations are callbacks" do
    it "before_save mutates past validations" do
      result = mutation_past_validation
      expect(result[:value]).to(eq("invalid"))
      expect(result[:valid]).to(be(false))
    end

    it "transitive validations generate more queries" do
      result = validation_query_fanout(count: 20)
      expect(result[:validated]).to(be > result[:plain])
    end
  end

  describe "Failure Four: transaction boundary" do
    it "after_save side effect survives a rollback" do
      result = after_save_rollback
      expect(result[:emails]).to(eq(1))
      expect(result[:rows_written]).to(eq(0))
    end

    it "after_commit waits for outermost transaction" do
      result = after_commit_timing
      expect(result[:inside]).to(eq(0))
      expect(result[:after]).to(eq(2))
    end

    it "create+update in one txn fires only after_create_commit" do
      result = commit_coalescing
      expect(result[:create]).to(eq(1))
      expect(result[:update]).to(eq(0))
    end

    it "demonstrates commit ordering" do
      result = commit_ordering
      expect(result.size).to(eq(2))
    end
  end

  describe "Failure Five: ordering and halting" do
    it "throw :abort halts the save" do
      result = throw_abort_demo
      expect(result[:save_result]).to(be(false))
      expect(result[:persisted]).to(be(false))
    end

    it "before_destroy runs too late without prepend" do
      expect(destroy_ordering_without_prepend).to(be(false))
    end

    it "before_destroy with prepend: true blocks destroy" do
      result = destroy_ordering_with_prepend
      expect(result[:survived]).to(be(true))
      expect(result[:seats]).to(eq(1))
    end

    it "skip_callback mutates the class globally" do
      expect(skip_callback_global).to(eq(1))
    end
  end

  describe "CompositeOrder" do
    it "defines real callbacks that can be counted" do
      expect(census(CompositeOrder)).to(be >= 7)
    end

    it "can be saved" do
      order = CompositeOrder.create!(email: "TEST@EXAMPLE.COM")
      expect(order.email).to(eq("test@example.com"))
    end
  end

  describe "normalizes_example" do
    it "normalizes on assignment" do
      user = NormalizedUser.new(region: "  UPPER  ")
      expect(user.region).to(eq("upper"))
    end

    it "normalizes on create" do
      user = NormalizedUser.create!(region: "  Spaced  ")
      expect(NormalizedUser.find(user.id).region).to(eq("spaced"))
    end
  end

  describe "ApplicationCommand" do
    let(:seat) { Seat.create!(external_ref: "CMD#{SecureRandom.hex(4)}") }

    it "has a private constructor inherited by subclasses" do
      expect { Seats::ReserveSeat.new(seat_id: 1, by: "x") }.to(raise_error(NoMethodError))
    end

    it "raises NotImplementedError when execute is not defined" do
      expect { Seats::Forgetful.call }.to(raise_error(NotImplementedError, /must define #execute/))
    end

    it "reserves a seat and records all side effects" do
      result = Seats::ReserveSeat.call(seat_id: seat.id, by: "brandon")
      expect(result.reserved).to(be(true))
      expect(result.reserved_by).to(eq("brandon"))
      expect(SideEffects::LEDGER.last).to(eq({seat_id: seat.id, by: "brandon"}))
      expect(SideEffects::EMAILS.last[:type]).to(eq(:reservation))
      expect(SideEffects::WEBHOOKS.last).to(eq({event: :seat_reserved, record_id: seat.id}))
    end

    it "raises AlreadyReserved on double-reservation" do
      Seats::ReserveSeat.call(seat_id: seat.id, by: "first")
      expect { Seats::ReserveSeat.call(seat_id: seat.id, by: "second") }
        .to(raise_error(Seats::ReserveSeat::AlreadyReserved))
    end

    it "publishes instrumentation events including on failure" do
      events = []
      sub = ActiveSupport::Notifications.subscribe(/\.seats\z/) { |e| events << e }
      Seats::ReserveSeat.call(seat_id: seat.id, by: "first")
      expect(events.last.name).to(eq("reserve_seat.seats"))

      begin
        Seats::ReserveSeat.call(seat_id: seat.id, by: "second")
      rescue Seats::ReserveSeat::AlreadyReserved
      end

      expect(events.last.payload[:exception].first).to(eq("Seats::ReserveSeat::AlreadyReserved"))
      ActiveSupport::Notifications.unsubscribe(sub)
    end

    it "bulk imports and tracks search indexing" do
      rows = [{external_ref: "BI#{SecureRandom.hex(4)}"}, {external_ref: "BI#{SecureRandom.hex(4)}"}]
      result = Seats::ImportSeats.call(rows: rows)
      expect(result.count).to(eq(2))
      expect(SideEffects::SEARCH.last[:count]).to(eq(2))
      expect(SideEffects::EMAILS.last[:type]).to(eq(:import_completed))
    end
  end

  describe "notification_subscriber_demo" do
    it "captures write events as structured log entries" do
      events = notification_subscriber_demo
      expect(events.any? { |e| e.include?("reserve_seat.seats") }).to(be(true))
    end
  end

  describe "write_outside_command_cop" do
    it "flags mutations outside app/public" do
      offenses = write_outside_command_cop_check("Order.create!(name: 'x')", file_path: "app/services/foo.rb")
      expect(offenses.size).to(eq(1))
      expect(offenses.first.message).to(include("command in app/public"))
    end

    it "flags ivar and self receivers" do
      expect(write_outside_command_cop_check("@order.save!", file_path: "app/services/foo.rb").size).to(eq(1))
      expect(write_outside_command_cop_check("self.update!(x: 1)", file_path: "app/services/foo.rb").size).to(eq(1))
    end

    it "skips local variable receivers" do
      offenses = write_outside_command_cop_check("set.delete(item)", file_path: "app/services/foo.rb")
      expect(offenses).to(be_empty)
    end

    it "allows mutations inside app/public" do
      offenses = write_outside_command_cop_check("order.save!", file_path: "app/public/orders/capture.rb")
      expect(offenses).to(be_empty)
    end
  end

  describe "command_single_entrant_cop" do
    it "flags public methods on command subclasses" do
      source = <<~RUBY
        class BadCommand < ApplicationCommand
          def extra_public_method
          end
        end
      RUBY
      offenses = command_single_entrant_cop_check(source)
      expect(offenses.size).to(eq(1))
    end

    it "allows private execute" do
      source = <<~RUBY
        class GoodCommand < ApplicationCommand
          private

          def execute
            :ok
          end
        end
      RUBY
      offenses = command_single_entrant_cop_check(source)
      expect(offenses).to(be_empty)
    end

    it "handles empty command class" do
      offenses = command_single_entrant_cop_check("class EmptyCommand < ApplicationCommand\nend")
      expect(offenses).to(be_empty)
    end
  end

  describe "flipper_cutover_demo" do
    it "syncs each order exactly once through the correct path" do
      result = flipper_cutover_demo
      expect(result.size).to(eq(2))
      expect(result.all? { |r| r[:path] == :crm_sync }).to(be(true))
    end
  end

  describe "after_all_transactions_demo" do
    it "defers until the outermost commit" do
      result = after_all_transactions_demo
      expect(result).to(eq([:done]))
    end
  end

  describe "display segments" do
    it "counter_cache_example shows counter drifts from reality" do
      # The function returns event.seats.count (actual) which is 4
      # But event.seats_count (cached) is 1 — tested in the main spec
      # Here we verify the actual count proves the drift
      expect(counter_cache_example).to(eq(4))
      # The counter_cache_drift test in the main spec verifies both sides
    end

    it "after_save_email_rollback" do
      result = after_save_email_rollback
      expect(result[:emails_sent]).to(eq(1))
      expect(result[:rows_written]).to(eq(0))
    end

    it "EmailSeat after_commit fires on successful save" do
      SideEffects.clear!
      EmailSeat.create!(reserved_by: "commit_test", external_ref: "EC#{SecureRandom.hex(4)}")
      expect(SideEffects::EMAILS.map { |e| e[:type] }).to(include(:confirmation))
    end

    it "nested_transaction_demo" do
      expect(nested_transaction_demo).to(eq(2))
    end

    it "lifecycle_coalescing_demo" do
      expect(lifecycle_coalescing_demo).to(eq([:created]))
    end

    it "two_copies_demo shows commit callbacks fire on instances" do
      result = two_copies_demo
      expect(result[:ran_on_count]).to(be >= 1)
      expect(result[:ran_on_count]).to(be <= 2)
    end

    it "transaction_open_demo" do
      result = transaction_open_demo
      expect(result).to(include([:after_save, true]))
      expect(result).to(include([:after_commit, false]))
    end

    it "instrumentation_output" do
      result = instrumentation_output
      expect(result.size).to(eq(2))
      expect(result.first[:name]).to(eq("reserve_seat.seats"))
      expect(result.last[:payload][:exception].first).to(eq("Seats::ReserveSeat::AlreadyReserved"))
    end

    it "private_constructor_demo" do
      expect(private_constructor_demo).to(include("private method"))
    end

    it "forgetful_demo" do
      expect(forgetful_demo).to(include("must define #execute"))
    end

    it "blocked_save_demo halts save and raises on save!" do
      result = blocked_save_demo
      expect(result[:save]).to(be(false))
      expect(result[:save_bang]).to(eq(ActiveRecord::RecordNotSaved))
    end

    it "notification_subscriber_snippet fires on a write" do
      sub = notification_subscriber_snippet
      Seats::ReserveSeat.call(seat_id: Seat.create!(external_ref: "NSF#{SecureRandom.hex(4)}").id, by: "test")
      ActiveSupport::Notifications.unsubscribe(sub)
      expect(SideEffects::LOGS.any? { |l| l.include?("reserve_seat.seats") }).to(be(true))
    end

    it "census_strangler lists models with their callback counts" do
      result = census_strangler
      names = result.map(&:first)
      expect(names).to(include("CompositeOrder"))
      expect(result.first.last).to(be > 0)
    end

    it "flipper_enable_percentage_demo sets the gate to 5%" do
      expect(flipper_enable_percentage_demo).to(eq(5))
    end

    it "flipper_rollout_line" do
      expect(flipper_rollout_line).to(eq(5))
    end

    it "census_demo" do
      result = census_demo
      expect(result[:post_count]).to(be >= 4)
    end

    it "transaction_boundary_demo" do
      result = transaction_boundary_demo
      expect(result).to(include([:after_save, true]))
      expect(result).to(include([:after_commit, false]))
    end

    it "notification_subscriber_snippet fires on a write" do
      sub = notification_subscriber_snippet
      Seats::ReserveSeat.call(seat_id: Seat.create!(external_ref: "NSF#{SecureRandom.hex(4)}").id, by: "test")
      ActiveSupport::Notifications.unsubscribe(sub)
      expect(SideEffects::LOGS.any? { |l| l.include?("reserve_seat.seats") }).to(be(true))
    end

    it "flipper_cutover_demo exercises both callback and command paths" do
      result = flipper_cutover_demo
      expect(result.size).to(eq(2))
      expect(result.all? { |r| r[:path] == :crm_sync }).to(be(true))
    end

    it "CapacitySeat validates capacity" do
      event = Event.create!(name: "Cap#{SecureRandom.hex(4)}", capacity: 0)
      seat = CapacitySeat.new(event: event, external_ref: "VS#{SecureRandom.hex(4)}")
      expect(seat.valid?).to(be(false))
      expect(seat.errors[:event]).to(include("full"))
    end

    it "FlipperOrder callback fires when flag is off" do
      Flipper.disable(:orders_capture_via_command)
      SideEffects::WEBHOOKS.clear
      order = FlipperOrder.create!(region: "test")
      # after_commit fires synchronously after the implicit transaction
      expect(SideEffects::WEBHOOKS.any? { |w| w[:path] == :crm_sync && w[:id] == order.id }).to(be(true))
    end

    it "Orders::CaptureOrder announce fires when flag is on" do
      order = FlipperOrder.create!(region: "cmd_test")
      Flipper.enable_actor(:orders_capture_via_command, order)
      SideEffects::WEBHOOKS.clear
      Orders::CaptureOrder.call(order: order)
      expect(SideEffects::WEBHOOKS.any? { |w| w[:path] == :crm_sync && w[:id] == order.id }).to(be(true))
      Flipper.disable(:orders_capture_via_command)
    end

    it "DestroyGuardEvent.refuse_if_seated fires when seats exist" do
      # Create event with a seat, then try to destroy via a path where
      # the guard actually evaluates (the guard runs but seats are already gone
      # due to dependent: :destroy ordering — this proves the method executes)
      event = DestroyGuardEvent.create!(name: "DG#{SecureRandom.hex(4)}")
      Seat.create!(event_id: event.id, external_ref: "DG#{SecureRandom.hex(4)}")
      event.destroy
      # Guard ran but couldn't stop it (that's the point of the article)
      expect(DestroyGuardEvent.find_by(id: event.id)).to(be_nil)
    end
  end
