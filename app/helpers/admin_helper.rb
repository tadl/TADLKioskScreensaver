# frozen_string_literal: true

module AdminHelper
  RESOURCE_TITLES = { "slides" => "Slides", "kiosks" => "Kiosks", "kiosk_groups" => "Kiosk groups",
    "hosts" => "Hosts", "user_permissions" => "Users & access", "permissions" => "Permissions" }.freeze

  def admin_resource_title = RESOURCE_TITLES.fetch(controller_name, "Overview")

  def admin_accessible_kiosk_ids
    @admin_accessible_kiosk_ids ||= current_user.accessible_kiosk_ids
  end

  def diagnostic_value(key, value)
    return "Not reported" if value.nil?
    return human_duration(value) if %i[uptime_seconds wireguard_handshake_age_seconds].include?(key)
    if key == :wireguard_latest_handshake_at && value.to_i.positive?
      return Time.zone.at(value.to_i).to_s
    end
    if %i[tab_url href source].include?(key)
      uri = URI.parse(value.to_s)
      return link_to(value, uri.to_s, target: "_blank", rel: "noopener", class: "admin-text-link") if uri.is_a?(URI::HTTP) && uri.host.present?
    end
    value.to_s
  rescue URI::InvalidURIError
    value.to_s
  end

  def admin_record_label(record)
    case record
    when Slide then record.title.presence || "Untitled slide"
    when UserPermission then "#{record.user.name.presence || record.user.email} · #{record.permission.name}"
    else record.name
    end
  end

  def admin_badge(text, tone = "neutral")
    tone = "neutral" unless %w[neutral success warning danger].include?(tone)
    tag.span(text, class: "admin-badge admin-badge-#{tone}")
  end

  def slide_schedule(slide)
    if slide.end_date && slide.end_date < Date.current
      admin_badge("Expired", "neutral")
    elsif slide.start_date && slide.start_date > Date.current
      admin_badge("Upcoming", "warning")
    else
      admin_badge("Active", "success")
    end
  end

  def admin_thumbnail(slide, size: 160)
    attachment = slide.image_attachment
    return tag.div("No image", class: "admin-image-placeholder") unless attachment&.persisted? && attachment.blob.persisted?

    blob = attachment.blob
    source = blob.variable? ? blob.variant(resize_to_limit: [size * 2, size * 2]) : blob
    link_to url_for(blob), target: "_blank", rel: "noopener", data: { turbo: false }, class: "admin-thumbnail" do
      image_tag source, alt: slide.title.to_s, loading: "lazy"
    end
  end

  def resource_creation_allowed?
    resource_class != UserPermission && can?(:create, resource_class)
  end

  def admin_nav_link(label, path, symbol)
    active = path == admin_root_path ? controller_name == "dashboard" : request.path.start_with?(path)
    link_to path, class: "admin-nav-link #{'is-current' if active}", aria: { current: ("page" if active) } do
      admin_icon(symbol) + tag.span(label)
    end
  end

  def admin_icon(name)
    paths = {
      "overview" => "M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z",
      "slides" => "M3 4h18v16H3z M3 16l5-5 4 4 3-3 6 6 M15 8h.01",
      "kiosks" => "M3 3h18v14H3z M8 21h8 M12 17v4",
      "groups" => "M3 6h7l2 2h9v13H3z M3 6V3h7l2 3",
      "hosts" => "M4 3h16v7H4z M4 14h16v7H4z M7 6h.01 M7 17h.01",
      "users" => "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2 M21 21v-2a4 4 0 0 0-3-3.87 M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8 M17 3.13a4 4 0 0 1 0 7.75",
      "permissions" => "M12 3l8 4v5c0 5-8 9-8 9s-8-4-8-9V7z M8 12l3 3 5-6"
    }
    tag.svg(viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": 1.6, "stroke-linecap": "round", "stroke-linejoin": "round", aria: { hidden: true }) do
      tag.path(d: paths.fetch(name))
    end
  end
end
