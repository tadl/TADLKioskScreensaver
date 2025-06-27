# TADL Kiosk Screensaver

A Rails application to manage and serve full‑screen slideshows on library kiosks. Allows uploading 1920×1080 images, scheduling display durations, and assigning slides to individual kiosks via an admin interface.

## Key Features

* **Slide Management**: Upload 1920×1080 images, set display duration, optional start/end dates.
* **Kiosk Assignment**: Assign slides to one or more kiosks.
* **User Permissions**: Granular access control with CanCanCan and user/group permissions.
* **Admin UI**: Full CRUD admin interface powered by RailsAdmin.
* **Image Storage**: ActiveStorage for uploads; local disk in development, mounted storage in production.

## Technology Stack

* Ruby 3.2.8, Rails 7.1.5
* PostgreSQL
* RailsAdmin 3.3.0
* CanCanCan
* ActiveStorage
* Importmap & Hotwire (Turbo)
* dotenv (development)
* Dokku / Heroku deployment

## Getting Started

### Prerequisites

* Ruby 3.2.x
* PostgreSQL
* Bundler (`gem install bundler`)

### Setup (Development)

1. **Clone repository**

   ```bash
   git clone https://github.com/tadl/TADLKioskScreensaver.git
   cd TADLKioskScreensaver
   ```

2. **Install gems**

   ```bash
   bundle install
   ```

3. **Environment variables**

   * Copy `.env.example` to `.env` and fill in credentials (DATABASE\_URL, SECRET\_KEY\_BASE, etc.).
   * Uses [dotenv](https://github.com/bkeepers/dotenv) to load `.env` in development.

4. **Database setup**

   ```bash
   rails db:create db:migrate
   ```

5. **Start server**

   ```bash
   bin/rails server
   ```

6. **Access admin**
   Navigate to `http://localhost:3000/admin` and sign in via configured OAuth.

## Configuration

### Development

* Environment variables live in `.env` (loaded via dotenv).
* ActiveStorage uses local disk (in `storage/`).

## Contributing

1. Fork the repo
2. Create a feature branch
3. Submit a pull request

---

*This application powers digital signage for library kiosks. Adjust configurations as needed per environment.*

