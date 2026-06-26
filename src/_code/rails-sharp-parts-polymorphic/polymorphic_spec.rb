# frozen_string_literal: true

require_relative "polymorphic"

RSpec.describe "Rails: The Sharp Parts — Polymorphic Type" do
  let(:seeds) { seed! }
  let(:event) { seeds[:event] }
  let(:order) { seeds[:order] }
  let(:seat) { seeds[:seat] }
  let(:proxy) { EventProxy.new(event) }

  describe "schema" do
    it "has notable_type and notable_id columns" do
      cols = schema_columns
      expect(cols.any? { |c| c.include?("notable_type") }).to be(true)
      expect(cols.any? { |c| c.include?("notable_id") }).to be(true)
    end

    it "has a composite index on [notable_type, notable_id]" do
      indexes = schema_index
      expect(indexes.first).to include("notable_type")
      expect(indexes.first).to include("notable_id")
    end

    it "has no foreign keys" do
      expect(schema_foreign_keys).to be_empty
    end
  end

  describe "shared IDs" do
    it "all three notes share notable_id but differ by type" do
      event  # force seed
      notes = notes_share_id
      ids = notes.map { |n| n[:notable_id] }.uniq
      expect(ids.size).to eq(1)
      expect(notes.map { |n| n[:notable_type] }.sort).to eq(%w[Event Order Seat])
    end
  end

  describe "well-formed find" do
    it "includes both type and id in the WHERE clause" do
      sql = well_formed_find(event)
      expect(sql).to include("notable_type")
      expect(sql).to include("notable_id")
    end
  end

  describe "EventProxy identity" do
    it "fails the ActiveRecord::Base check" do
      info = proxy_identity(proxy)
      expect(info[:class]).to eq(EventProxy)
      expect(info[:is_a_ar_base]).to be(false)
      expect(info[:kind_of_event]).to be(false)
      expect(info[:responds_to_getobj]).to be(true)
      expect(info[:wrapped_class]).to eq(Event)
    end

    it "delegates methods but overrides price_cents" do
      expect(proxy.price_cents).to eq(0)
    end
  end

  describe "proxy find drops the type" do
    it "produces SQL without notable_type" do
      sql = proxy_find(proxy)
      expect(sql).not_to include("notable_type")
      expect(sql).to include("notable_id")
    end
  end

  describe "proxy leak" do
    it "returns all 3 notes instead of 1" do
      result = proxy_leak(event, proxy)
      expect(result[:event_notes_count]).to eq(1)
      expect(result[:proxy_query_count]).to eq(3)
      expect(result[:leaked_notes].size).to eq(3)
    end
  end

  describe "proxy writes are fine" do
    it "writes through association correctly" do
      result = proxy_writes_fine(proxy)
      expect(result[:type_is_correct]).to be(true)
      expect(result[:body]).to eq("written through proxy")
    end
  end

  describe "fix: unwrap" do
    it "restores the type clause and returns 1 row" do
      result = fix_unwrap(proxy)
      expect(result[:sql]).to include("notable_type")
      expect(result[:count]).to eq(1)
    end
  end

  describe "exclusive belongs_to with CHECK" do
    before { ExclusiveNote.delete_all }

    it "shows the schema" do
      expect(exclusive_notes_schema).to include("check_constraint")
    end

    it "accepts one owner, rejects two, zero, and ghost" do
      results = exclusive_belongs_to_demo(event, order)
      expect(results[0]).to include("accepted")
      expect(results[1]).to include("rejected by CHECK")
      expect(results[2]).to include("rejected by CHECK")
      expect(results[3]).to include("rejected by FK")
    end
  end

  describe "EXPLAIN plans" do
    it "explain_with_type returns a plan" do
      expect(explain_with_type).to be_a(String)
    end

    it "explain_without_type returns a plan" do
      expect(explain_without_type).to be_a(String)
    end
  end

  describe "type injection" do
    it "raises NameError for a non-existent class" do
      expect { injected_type }.to raise_error(NameError)
    end

    it "resolves to the wrong table when type is swapped" do
      result = type_confusion(event)
      expect(result).to be_a(Order)
    end

    it "repoints a note by flipping the type string" do
      note = event.notes.first
      before, after = repoint(note)
      expect(before).to eq(Event)
      expect(after).to eq(Order)
    end
  end

  describe "joins" do
    it "cannot join through a polymorphic association" do
      result = join_through_notable
      expect(result).to include("polymorphic")
    end
  end

  describe "preload fanout" do
    it "fires multiple queries for polymorphic preload" do
      expect(preload_fanout).to be >= 3
    end
  end

  describe "orphans" do
    it "note survives after owner is deleted" do
      result = orphaned_note
      expect(result[:present]).to be(true)
      expect(result[:notable]).to be_nil
    end
  end

  describe "stale strings" do
    it "old notes invisible after namespace change" do
      result = stale_after_namespace(event)
      expect(result[:old_count]).to eq(1)
      expect(result[:new_count]).to eq(0)
    end
  end
end
