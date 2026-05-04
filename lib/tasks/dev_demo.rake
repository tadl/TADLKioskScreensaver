# frozen_string_literal: true

namespace :dev do
  desc "Create idempotent demo kiosk groups, kiosks, slides, status, sessions, heartbeats, and logs"
  task seed_demo: :environment do
    unless Rails.env.development? || Rails.env.test?
      abort "dev:seed_demo only runs in development or test"
    end

    DemoData.seed!
  end

  desc "Remove demo data created by dev:seed_demo"
  task clear_demo: :environment do
    unless Rails.env.development? || Rails.env.test?
      abort "dev:clear_demo only runs in development or test"
    end

    DemoData.clear!
  end
end

module DemoData
  module_function

  SLIDE_SIZE = [1920, 1080].freeze
  GROUPS = [
    { name: "Demo Main Library", slug: "demo-main", location_shortname: "main" },
    { name: "Demo East Bay", slug: "demo-east-bay", location_shortname: "eastbay" },
    { name: "Demo Peninsula", slug: "demo-peninsula", location_shortname: "peninsula" }
  ].freeze

  SLIDES = [
    { title: "Demo Welcome", color: "#114b5f", accent: "#f3e9d2", display_seconds: 8, offset: -10, duration: 45 },
    { title: "Demo Events This Week", color: "#456990", accent: "#f45b69", display_seconds: 12, offset: -4, duration: 20 },
    { title: "Demo Library Card", color: "#028090", accent: "#f0f3bd", display_seconds: 10, offset: -1, duration: 30 },
    { title: "Demo Future Campaign", color: "#5f0f40", accent: "#fb8b24", display_seconds: 9, offset: 14, duration: 30 },
    { title: "Demo Expired Notice", color: "#333533", accent: "#ffd100", display_seconds: 7, offset: -45, duration: 10 },
    { title: "Demo Fallback Slide", color: "#252422", accent: "#eb5e28", display_seconds: 15, offset: -365, duration: nil, fallback: true }
  ].freeze

  def seed!
    ActiveRecord::Base.transaction do
      clear_runtime_rows!

      groups = GROUPS.map { |attrs| upsert_group(attrs) }
      kiosks = groups.flat_map.with_index { |group, index| upsert_kiosks(group, index) }
      slides = SLIDES.map.with_index { |attrs, index| upsert_slide(attrs, index) }

      assign_slides(kiosks, slides)
      create_status_sessions_and_logs(kiosks)

      puts "Demo data ready:"
      puts "  kiosk groups: #{groups.map(&:slug).join(', ')}"
      puts "  kiosks: #{kiosks.map(&:slug).join(', ')}"
      puts "  slides: #{slides.map(&:title).join(', ')}"
    end
  end

  def clear!
    ActiveRecord::Base.transaction do
      clear_runtime_rows!
      Slide.where("title LIKE 'Demo %'").find_each do |slide|
        slide.image.purge if slide.image.attached?
        slide.destroy!
      end
      Kiosk.where("slug LIKE 'demo-%'").destroy_all
      KioskGroup.where("slug LIKE 'demo-%'").destroy_all
      Host.where("name LIKE 'demo-kiosk-%'").destroy_all
    end

    puts "Demo data removed"
  end

  def upsert_group(attrs)
    KioskGroup.find_or_initialize_by(slug: attrs[:slug]).tap do |group|
      group.assign_attributes(attrs)
      group.save!
    end
  end

  def upsert_kiosks(group, group_index)
    2.times.map do |offset|
      number = (group_index * 2) + offset + 1
      slug = "demo-kiosk-#{number.to_s.rjust(2, '0')}"
      Kiosk.find_or_initialize_by(slug: slug).tap do |kiosk|
        kiosk.assign_attributes(
          name: "Demo Kiosk #{number}",
          catalog_url: "https://catalog.tadl.org/?demo_kiosk=#{number}",
          location: group.name,
          kiosk_group: group
        )
        kiosk.save!
      end
    end
  end

  def upsert_slide(attrs, index)
    start_date = Date.current + attrs[:offset]
    end_date = attrs[:duration] ? start_date + attrs[:duration] : nil

    Slide.find_or_initialize_by(title: attrs[:title]).tap do |slide|
      slide.assign_attributes(
        link: "https://www.tadl.org/demo/#{attrs[:title].parameterize}",
        display_seconds: attrs[:display_seconds],
        start_date: start_date,
        end_date: end_date,
        fallback: attrs[:fallback] || false
      )
      slide.save!
      attach_demo_image(slide, attrs, index)
    end
  end

  def assign_slides(kiosks, slides)
    active_slides = slides.reject(&:fallback?)
    fallback_slide = slides.find(&:fallback?)

    kiosks.each_with_index do |kiosk, index|
      assigned = active_slides.rotate(index).first(3)
      assigned << fallback_slide if fallback_slide
      kiosk.slides = assigned.compact
      kiosk.save!
    end
  end

  def create_status_sessions_and_logs(kiosks)
    kiosks.each_with_index do |kiosk, index|
      host_name = kiosk.slug
      Host.find_or_create_by!(name: host_name)
      state = index.even? ? :screensaver : :opac
      KioskStatus.mark!(kiosk: kiosk, host: host_name, state: state, now: (index + 1).minutes.ago)

      KioskHeartbeat.find_or_initialize_by(kiosk_id: host_name).tap do |heartbeat|
        heartbeat.assign_attributes(
          last_seen_at: Time.current - index.minutes,
          uptime_seconds: 86_400 + (index * 900),
          kiosk_service: "running",
          chromium_pids: 2 + index,
          chromium_devtools_ok: true,
          chromium_devtools_http: "200",
          chromium_devtools_ms: 20 + index,
          raw_payload: {
            "chromium_devtools_ok" => true,
            "chromium_devtools_http" => "200",
            "chromium_devtools_ms" => 20 + index
          }
        )
        heartbeat.save!
      end

      create_sessions(kiosk, host_name, index)
      create_logs(host_name, index)
    end
  end

  def create_sessions(kiosk, host_name, index)
    5.times do |day_offset|
      started_at = (day_offset + 1).days.ago.change(hour: 9 + index, min: 15)
      KioskSession.find_or_create_by!(
        kiosk_code: kiosk.slug,
        host: host_name,
        started_at: started_at
      ) do |session|
        session.ended_at = started_at + (20 + index + day_offset).minutes
      end
    end
  end

  def create_logs(host_name, index)
    3.times do |offset|
      occurred_at = Time.current - (offset * 15 + index).minutes
      KioskLog.find_or_create_by!(
        kiosk_id: host_name,
        occurred_at: occurred_at,
        message: "Demo kiosk event #{offset + 1}"
      ) do |log|
        log.level = offset.zero? ? "info" : "warn"
        log.raw_payload = {
          "event" => {
            "kind" => "demo",
            "message" => log.message,
            "tab_url" => "https://catalog.tadl.org/?host=#{host_name}"
          },
          "envelope" => { "sent_at" => occurred_at.iso8601 },
          "request" => { "remote_ip" => "127.0.0.1", "user_agent" => "demo-data" }
        }
      end
    end
  end

  def attach_demo_image(slide, attrs, index)
    if slide.image.attached? &&
        slide.image.blob.content_type == "image/png" &&
        slide.image.blob.metadata["width"] == SLIDE_SIZE.first
      return
    end

    slide.image.purge if slide.image.attached?
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(png_for(attrs, index)),
      filename: "#{attrs[:title].parameterize}.png",
      content_type: "image/png",
      metadata: { "width" => SLIDE_SIZE.first, "height" => SLIDE_SIZE.last },
      identify: false
    )
    slide.image.attach(blob)
    slide.image.blob.update!(
      metadata: slide.image.blob.metadata.merge("width" => SLIDE_SIZE.first, "height" => SLIDE_SIZE.last)
    )
  end

  def png_for(attrs, index)
    file = Tempfile.new(["demo-slide", ".png"])
    today = Date.current.strftime("%B %-d, %Y")
    font = demo_font_path
    font_args = font ? ["-font", font] : []

    ok = system(
      "magick",
      "-size", "1920x1080",
      "xc:#{attrs[:color]}",
      "-fill", attrs[:accent],
      "-draw", "circle #{240 + (index * 110)},220 #{420 + (index * 110)},220",
      "-fill", attrs[:accent],
      "-draw", "circle 1680,880 1940,880",
      "-fill", attrs[:accent],
      "-draw", "rectangle 120,710 1800,716",
      *font_args,
      "-fill", attrs[:accent],
      "-pointsize", "48",
      "-annotate", "+120+180", "TADL Kiosk Demo",
      "-fill", "white",
      "-pointsize", "112",
      "-annotate", "+120+470", attrs[:title],
      "-fill", "rgba(255,255,255,0.86)",
      "-pointsize", "46",
      "-annotate", "+120+590", "Generated demo slide for local development testing",
      "-fill", "rgba(255,255,255,0.72)",
      "-pointsize", "34",
      "-annotate", "+120+810", "1920x1080 PNG - #{today}",
      file.path
    )

    raise "ImageMagick failed to generate #{attrs[:title]}" unless ok

    file.binmode
    file.read
  ensure
    file&.close!
  end

  def demo_font_path
    [
      "/System/Library/Fonts/SFNS.ttf",
      "/System/Library/Fonts/SFNSMono.ttf",
      "/Library/Fonts/Arial.ttf",
      "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    ].find { |path| File.exist?(path) }
  end

  def clear_runtime_rows!
    host_names = Kiosk.where("slug LIKE 'demo-%'").pluck(:slug)
    KioskStatus.where(host: host_names).delete_all
    KioskSession.where(host: host_names).delete_all
    KioskHeartbeat.where(kiosk_id: host_names).delete_all
    KioskLog.where(kiosk_id: host_names).delete_all
  end
end
