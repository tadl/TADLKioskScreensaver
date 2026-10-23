# frozen_string_literal: true

require "csv"

class Admin::Export
  ASSOCIATIONS = {
    "Slide" => { "kiosks" => %w[id name slug] },
    "Kiosk" => { "slides" => %w[id title display_seconds start_date end_date fallback], "kiosk_group" => %w[id name slug] },
    "KioskGroup" => { "kiosks" => %w[id name slug] },
    "UserPermission" => { "user" => %w[id email name], "permission" => %w[id name],
      "kiosks" => %w[id name slug], "kiosk_groups" => %w[id name slug] }
  }.freeze

  def initialize(records, fields, ability: nil)
    @records = records
    @fields = fields
    @ability = ability
  end

  def json = rows.to_json
  def xml = rows.to_xml(root: "records", children: "record")

  def csv
    CSV.generate(headers: @fields, write_headers: true) do |output|
      rows.each do |row|
        output << @fields.map { |field| csv_value(row[field]) }
      end
    end
  end

  private

  def rows
    @records.map do |record|
      row = record.attributes.slice(*@fields)
      ASSOCIATIONS.fetch(record.class.name, {}).slice(*@fields).each do |association, columns|
        related = record.public_send(association)
        if @ability && %w[Slide Kiosk KioskGroup].include?(record.class.name)
          related = if related.respond_to?(:to_ary)
            related.to_ary.select { |item| @ability.can?(:read, item) }
          elsif related && @ability.cannot?(:read, related)
            nil
          else
            related
          end
        end
        row[association] = related.as_json(only: columns)
      end
      row
    end
  end

  # Spreadsheet applications can execute cells beginning with formula markers.
  def csv_value(value)
    value = value.to_json if value.is_a?(Array) || value.is_a?(Hash)
    value.is_a?(String) && value.match?(/\A[=+@\-\t\r\n]/) ? "'#{value}" : value
  end
end
